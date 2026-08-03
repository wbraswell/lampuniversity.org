#!/usr/bin/env perl

use strict;
use warnings;

use Digest::SHA qw(sha256_hex);
use File::Basename qw(basename dirname fileparse);
use Fcntl qw(:flock);
use File::Path qw(make_path);
use Getopt::Long qw(GetOptionsFromArray);
use HTTP::Tiny;
use JSON::PP qw(decode_json encode_json);
use MIME::Base64 qw(encode_base64);
use POSIX qw(strftime);

our $VERSION = '0.008';

my $MAX_UPLOAD_BYTES = 20 * 1024 * 1024;
my $DEFAULT_DROPBOX_ROOT = '/home_wbraswell/school/utd/whisperx';
my $DROPBOX_API_BASE = $ENV{WHISPERX_DROPBOX_API_BASE} // 'https://api.dropboxapi.com/2';
my $DROPBOX_CONTENT_BASE = $ENV{WHISPERX_DROPBOX_CONTENT_BASE} // 'https://content.dropboxapi.com/2';
my $DROPBOX_OAUTH_URL = $ENV{WHISPERX_DROPBOX_OAUTH_URL} // 'https://api.dropboxapi.com/oauth2/token';

sub usage {
    die <<'USAGE';
Usage:
  whisperx_dropbox_checkpoint_sync.pl prepare [options]
  whisperx_dropbox_checkpoint_sync.pl restore [options]
  whisperx_dropbox_checkpoint_sync.pl sync-once [options]
  whisperx_dropbox_checkpoint_sync.pl watch [options] --watch-pid PID
  whisperx_dropbox_checkpoint_sync.pl download-file [options] --dropbox-path PATH --local-path PATH
  whisperx_dropbox_checkpoint_sync.pl bootstrap-download [options] --local-directory PATH [--input-name NAME]

Common options:
  --credentials-file PATH
  --token-cache-file PATH
  --dropbox-root PATH
  --input-file PATH
  --checkpoint-dir PATH
  --run-log PATH
  --output-dir PATH
  --job-state-file PATH
  --source-version TEXT
  --http-timeout SECONDS

Credentials are read from environment variables or a mode-0600 file containing:
  DROPBOX_ACCESS_TOKEN=...

For renewable credentials, use:
  DROPBOX_APP_KEY=...
  DROPBOX_APP_SECRET=...
  DROPBOX_REFRESH_TOKEN=...
USAGE
}

sub timestamp_utc {
    return strftime('%Y%m%d_%H%M%S', gmtime(time));
}

sub read_text_file {
    my ($path) = @_;
    open my $file_handle, '<', $path or die "Unable to read $path: $!\n";
    local $/ = undef;
    my $content = <$file_handle>;
    close $file_handle or die "Unable to close $path: $!\n";
    return $content;
}

sub write_text_file_atomic {
    my ($path, $content) = @_;
    make_path(dirname($path));
    my $temporary_path = $path . '.tmp.' . $$;
    open my $file_handle, '>', $temporary_path
        or die "Unable to write $temporary_path: $!\n";
    print {$file_handle} $content;
    close $file_handle or die "Unable to close $temporary_path: $!\n";
    rename $temporary_path, $path
        or die "Unable to replace $path with $temporary_path: $!\n";
    return;
}

sub file_sha256 {
    my ($path) = @_;
    open my $file_handle, '<', $path or die "Unable to read $path: $!\n";
    binmode $file_handle;
    my $digest = Digest::SHA->new(256);
    $digest->addfile($file_handle);
    close $file_handle or die "Unable to close $path: $!\n";
    return $digest->hexdigest;
}

sub sanitize_name {
    my ($name) = @_;
    $name =~ s/[^A-Za-z0-9._-]+/_/g;
    $name =~ s/^_+//;
    $name =~ s/_+$//;
    return length $name ? $name : 'whisperx-job';
}

sub percent_encode {
    my ($value) = @_;
    $value =~ s/([^A-Za-z0-9\-._~])/sprintf('%%%02X', ord($1))/eg;
    return $value;
}

sub load_credentials {
    my ($credentials_file) = @_;
    my %credentials;

    for my $key (qw(DROPBOX_ACCESS_TOKEN DROPBOX_APP_KEY DROPBOX_APP_SECRET DROPBOX_REFRESH_TOKEN)) {
        if (defined $ENV{$key} && length $ENV{$key}) {
            $credentials{$key} = $ENV{$key};
        }
    }

    if (defined $credentials_file && length $credentials_file && -f $credentials_file) {
        my $credential_mode = (stat $credentials_file)[2] & 07777;
        die "Dropbox credentials file must not be accessible by group or others: $credentials_file\n"
            if $credential_mode & 0077;
        open my $file_handle, '<', $credentials_file
            or die "Unable to read Dropbox credentials file $credentials_file: $!\n";
        while (my $line = <$file_handle>) {
            chomp $line;
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
            next if !length $line || $line =~ /^#/;
            my ($key, $value) = split /=/, $line, 2;
            next if !defined $value;
            $key =~ s/^\s+|\s+$//g;
            $value =~ s/^\s+|\s+$//g;
            $value =~ s/^(['"])(.*)\1$/$2/;
            if ($key =~ /\A(?:DROPBOX_ACCESS_TOKEN|DROPBOX_APP_KEY|DROPBOX_APP_SECRET|DROPBOX_REFRESH_TOKEN)\z/) {
                $credentials{$key} = $value;
            }
        }
        close $file_handle or die "Unable to close Dropbox credentials file $credentials_file: $!\n";
    }

    my $has_refresh =
        length($credentials{DROPBOX_APP_KEY} // q{})
        && length($credentials{DROPBOX_APP_SECRET} // q{})
        && length($credentials{DROPBOX_REFRESH_TOKEN} // q{});
    my $has_access = length($credentials{DROPBOX_ACCESS_TOKEN} // q{});

    if (!$has_refresh && !$has_access) {
        die "Dropbox credentials are unavailable. Set DROPBOX_ACCESS_TOKEN or provide "
            . "DROPBOX_APP_KEY, DROPBOX_APP_SECRET, and DROPBOX_REFRESH_TOKEN.\n";
    }

    return \%credentials;
}

sub refresh_access_token {
    my ($http, $credentials, $token_cache_file) = @_;

    if (
        length($credentials->{DROPBOX_APP_KEY} // q{})
        && length($credentials->{DROPBOX_APP_SECRET} // q{})
        && length($credentials->{DROPBOX_REFRESH_TOKEN} // q{})
    ) {
        if (defined $token_cache_file && length $token_cache_file && -f $token_cache_file) {
            my $cached = eval { decode_json(read_text_file($token_cache_file)) };
            if (
                ref $cached eq 'HASH'
                && length($cached->{access_token} // q{})
                && ($cached->{expires_at} // 0) > time + 120
            ) {
                return $cached->{access_token};
            }
        }

        my $authorization = encode_base64(
            $credentials->{DROPBOX_APP_KEY} . ':' . $credentials->{DROPBOX_APP_SECRET},
            q{},
        );
        my $content = 'grant_type=refresh_token&refresh_token='
            . percent_encode($credentials->{DROPBOX_REFRESH_TOKEN});
        my $response = $http->post(
            $DROPBOX_OAUTH_URL,
            {
                headers => {
                    'Authorization' => 'Basic ' . $authorization,
                    'Content-Type'  => 'application/x-www-form-urlencoded',
                },
                content => $content,
            },
        );
        if (!$response->{success}) {
            die "Dropbox OAuth token refresh failed with HTTP $response->{status}: "
                . ($response->{content} // q{}) . "\n";
        }
        my $payload = decode_json($response->{content});
        my $token = $payload->{access_token};
        die "Dropbox OAuth token refresh returned no access token.\n"
            if !defined $token || !length $token;
        if (defined $token_cache_file && length $token_cache_file) {
            my $expires_in = $payload->{expires_in} // 14400;
            write_text_file_atomic(
                $token_cache_file,
                encode_json({ access_token => $token, expires_at => time + $expires_in }) . "\n",
            );
            chmod 0600, $token_cache_file
                or die "Unable to protect Dropbox token cache $token_cache_file: $!\n";
        }
        return $token;
    }

    return $credentials->{DROPBOX_ACCESS_TOKEN};
}

sub make_context {
    my ($credentials_file, $token_cache_file, $http_timeout) = @_;
    for my $proxy_name (qw(http_proxy https_proxy all_proxy HTTP_PROXY HTTPS_PROXY ALL_PROXY)) {
        delete $ENV{$proxy_name}
            if defined $ENV{$proxy_name} && !length $ENV{$proxy_name};
    }
    my $http = HTTP::Tiny->new(
        agent      => 'WhisperX-Dropbox-Checkpoint-Sync/' . $VERSION,
        timeout    => $http_timeout,
        verify_SSL => 1,
    );
    my $credentials = load_credentials($credentials_file);
    my $token = refresh_access_token($http, $credentials, $token_cache_file);
    return {
        credentials => $credentials,
        http        => $http,
        token       => $token,
        token_cache => $token_cache_file,
    };
}

sub dropbox_json_request {
    my ($context, $endpoint, $payload, $allow_error) = @_;
    my $response = $context->{http}->post(
        $DROPBOX_API_BASE . '/' . $endpoint,
        {
            headers => {
                'Authorization' => 'Bearer ' . $context->{token},
                'Content-Type'  => 'application/json',
            },
            content => encode_json($payload),
        },
    );

    if ($response->{status} == 401) {
        $context->{token} = refresh_access_token($context->{http}, $context->{credentials}, $context->{token_cache});
        $response = $context->{http}->post(
            $DROPBOX_API_BASE . '/' . $endpoint,
            {
                headers => {
                    'Authorization' => 'Bearer ' . $context->{token},
                    'Content-Type'  => 'application/json',
                },
                content => encode_json($payload),
            },
        );
    }

    if (!$response->{success} && !$allow_error) {
        die "Dropbox API $endpoint failed with HTTP $response->{status}: "
            . ($response->{content} // q{}) . "\n";
    }
    return $response;
}

sub create_folder_if_missing {
    my ($context, $path) = @_;
    my $response = dropbox_json_request(
        $context,
        'files/create_folder_v2',
        { path => $path, autorename => JSON::PP::false },
        1,
    );
    return if $response->{success};
    return if ($response->{content} // q{}) =~ /path\/conflict\/folder/;
    die "Unable to create Dropbox folder $path: " . ($response->{content} // q{}) . "\n";
}

sub list_folder {
    my ($context, $path) = @_;
    my @entries;
    my $response = dropbox_json_request(
        $context,
        'files/list_folder',
        {
            path            => $path,
            recursive       => JSON::PP::false,
            include_deleted => JSON::PP::false,
            limit           => 2000,
        },
        1,
    );
    if (!$response->{success}) {
        return [] if ($response->{content} // q{}) =~ /path\/not_found/;
        die "Unable to list Dropbox folder $path: " . ($response->{content} // q{}) . "\n";
    }

    my $payload = decode_json($response->{content});
    push @entries, @{$payload->{entries} // []};
    while ($payload->{has_more}) {
        $response = dropbox_json_request(
            $context,
            'files/list_folder/continue',
            { cursor => $payload->{cursor} },
            0,
        );
        $payload = decode_json($response->{content});
        push @entries, @{$payload->{entries} // []};
    }
    return \@entries;
}

sub upload_content {
    my ($context, $local_path, $dropbox_path, $mode, $ignore_conflict) = @_;
    my $size = -s $local_path;
    die "Refusing to upload $local_path because it exceeds $MAX_UPLOAD_BYTES bytes.\n"
        if $size > $MAX_UPLOAD_BYTES;
    open my $file_handle, '<', $local_path or die "Unable to read $local_path: $!\n";
    binmode $file_handle;
    local $/ = undef;
    my $content = <$file_handle>;
    close $file_handle or die "Unable to close $local_path: $!\n";

    my $api_argument = {
        path            => $dropbox_path,
        mode            => $mode,
        autorename      => JSON::PP::false,
        mute            => JSON::PP::true,
        strict_conflict => JSON::PP::false,
    };
    my $response = $context->{http}->post(
        $DROPBOX_CONTENT_BASE . '/files/upload',
        {
            headers => {
                'Authorization'   => 'Bearer ' . $context->{token},
                'Content-Type'    => 'application/octet-stream',
                'Dropbox-API-Arg' => encode_json($api_argument),
            },
            content => $content,
        },
    );
    if ($response->{status} == 401) {
        $context->{token} = refresh_access_token($context->{http}, $context->{credentials}, $context->{token_cache});
        $response = $context->{http}->post(
            $DROPBOX_CONTENT_BASE . '/files/upload',
            {
                headers => {
                    'Authorization'   => 'Bearer ' . $context->{token},
                    'Content-Type'    => 'application/octet-stream',
                    'Dropbox-API-Arg' => encode_json($api_argument),
                },
                content => $content,
            },
        );
    }
    if (!$response->{success}) {
        return if $ignore_conflict && ($response->{content} // q{}) =~ /path\/conflict/;
        die "Dropbox upload failed for $dropbox_path with HTTP $response->{status}: "
            . ($response->{content} // q{}) . "\n";
    }
    return;
}

sub download_content {
    my ($context, $dropbox_path, $local_path) = @_;
    make_path(dirname($local_path));
    my $temporary_path = $local_path . '.tmp.' . $$;
    my $response;

    for my $attempt (1 .. 2) {
        open my $file_handle, '>', $temporary_path
            or die "Unable to write $temporary_path: $!\n";
        binmode $file_handle;
        $response = $context->{http}->request(
            'POST',
            $DROPBOX_CONTENT_BASE . '/files/download',
            {
                headers => {
                    'Authorization'   => 'Bearer ' . $context->{token},
                    'Dropbox-API-Arg' => encode_json({ path => $dropbox_path }),
                },
                data_callback => sub {
                    my ($chunk) = @_;
                    print {$file_handle} $chunk;
                },
            },
        );
        close $file_handle or die "Unable to close $temporary_path: $!\n";
        last if $response->{success};
        if ($response->{status} == 401 && $attempt == 1) {
            $context->{token} = refresh_access_token(
                $context->{http},
                $context->{credentials},
                $context->{token_cache},
            );
            next;
        }
        last;
    }

    if (!$response->{success}) {
        unlink $temporary_path;
        die "Dropbox download failed for $dropbox_path with HTTP $response->{status}: "
            . ($response->{content} // q{}) . "\n";
    }
    rename $temporary_path, $local_path
        or die "Unable to replace $local_path with $temporary_path: $!\n";
    return;
}

sub load_state {
    my ($state_path) = @_;
    return {} if !-f $state_path;
    return decode_json(read_text_file($state_path));
}

sub save_state {
    my ($state_path, $state) = @_;
    write_text_file_atomic($state_path, encode_json($state) . "\n");
    return;
}

sub derive_job_state {
    my ($input_file, $dropbox_root, $checkpoint_dir, $source_version) = @_;
    die "Input file does not exist: $input_file\n" if !-f $input_file;
    my ($stem) = fileparse(basename($input_file), qr/\.[^.]*/);
    my $audio_sha256 = file_sha256($input_file);
    my $job_name = sanitize_name($stem) . '__' . substr($audio_sha256, 0, 16);
    my $job_path = $dropbox_root . '/jobs/' . $job_name;
    return {
        format             => 'whisperx-dropbox-job-v1',
        sync_version       => $VERSION,
        source_version     => $source_version,
        dropbox_root       => $dropbox_root,
        job_name           => $job_name,
        job_path           => $job_path,
        input_name         => basename($input_file),
        input_size         => 0 + (-s $input_file),
        input_sha256       => $audio_sha256,
        checkpoint_dir     => $checkpoint_dir,
        prepared_at_utc    => timestamp_utc(),
    };
}

sub remote_paths {
    my ($state) = @_;
    return {
        current  => $state->{job_path} . '/checkpoints/current',
        history  => $state->{job_path} . '/checkpoints/history',
        outputs  => $state->{job_path} . '/outputs',
        manifest => $state->{job_path} . '/job-manifest.json',
    };
}

sub prepare_job {
    my ($context, $options) = @_;
    my $state = derive_job_state(
        $options->{input_file},
        $options->{dropbox_root},
        $options->{checkpoint_dir},
        $options->{source_version},
    );
    my $paths = remote_paths($state);
    create_folder_if_missing($context, $options->{dropbox_root} . '/jobs');
    create_folder_if_missing($context, $state->{job_path});
    create_folder_if_missing($context, $state->{job_path} . '/checkpoints');
    create_folder_if_missing($context, $paths->{current});
    create_folder_if_missing($context, $paths->{history});
    create_folder_if_missing($context, $paths->{outputs});

    make_path($options->{checkpoint_dir});
    save_state($options->{job_state_file}, $state);
    my $manifest_local = $options->{job_state_file} . '.manifest-upload';
    write_text_file_atomic($manifest_local, encode_json($state) . "\n");
    upload_content($context, $manifest_local, $paths->{manifest}, 'overwrite', 0);
    unlink $manifest_local;
    restore_checkpoints($context, $options, $state);
    print "Dropbox WhisperX job: $state->{job_path}\n";
    return $state;
}

sub restore_checkpoints {
    my ($context, $options, $state) = @_;
    $state //= load_state($options->{job_state_file});
    die "Dropbox job state is unavailable: $options->{job_state_file}\n"
        if !defined $state->{job_path};
    my $paths = remote_paths($state);
    my $entries = list_folder($context, $paths->{current});
    my %remote_by_name;
    for my $entry (@{$entries}) {
        next if ($entry->{'.tag'} // q{}) ne 'file';
        $remote_by_name{$entry->{name}} = $entry;
    }

    make_path($options->{checkpoint_dir});
    for my $name (sort grep { /\.json\z/ } keys %remote_by_name) {
        my $local_path = $options->{checkpoint_dir} . '/' . $name;
        my $remote_path = $remote_by_name{$name}->{path_display}
            // $remote_by_name{$name}->{path_lower};
        download_content($context, $remote_path, $local_path);
        my $sidecar_name = $name . '.sha256';
        if (exists $remote_by_name{$sidecar_name}) {
            my $sidecar_local = $local_path . '.sha256';
            my $sidecar_remote = $remote_by_name{$sidecar_name}->{path_display}
                // $remote_by_name{$sidecar_name}->{path_lower};
            download_content($context, $sidecar_remote, $sidecar_local);
            my ($expected) = split /\s+/, read_text_file($sidecar_local);
            my $actual = file_sha256($local_path);
            die "Restored checkpoint checksum mismatch for $local_path\n"
                if $actual ne $expected;
        }
        print "Restored checkpoint: $local_path\n";
    }
    return;
}

sub checkpoint_files {
    my ($checkpoint_dir) = @_;
    return [] if !-d $checkpoint_dir;
    opendir my $directory_handle, $checkpoint_dir
        or die "Unable to open $checkpoint_dir: $!\n";
    my @files = sort map { $checkpoint_dir . '/' . $_ }
        grep { /\.whisperx-[A-Za-z0-9-]+\.json\z/ && -f $checkpoint_dir . '/' . $_ }
        readdir $directory_handle;
    closedir $directory_handle or die "Unable to close $checkpoint_dir: $!\n";
    return \@files;
}

sub output_files {
    my ($options, $state) = @_;
    return [] if !defined $options->{output_dir} || !-d $options->{output_dir};
    my ($stem) = fileparse($state->{input_name}, qr/\.[^.]*/);
    my @suffixes = qw(.json .srt .vtt .tsv .txt .out .err .corrections.json);
    my @files;
    for my $suffix (@suffixes) {
        my $candidate = $options->{output_dir} . '/' . $stem . $suffix;
        push @files, $candidate if -f $candidate;
    }
    if (defined $options->{run_log} && -f $options->{run_log}) {
        push @files, $options->{run_log}
            if !grep { $_ eq $options->{run_log} } @files;
    }
    return \@files;
}

sub sync_once {
    my ($context, $options, $state) = @_;
    make_path($options->{checkpoint_dir});
    my $lock_path = $options->{checkpoint_dir} . '/.dropbox-sync.lock';
    open my $lock_handle, '>>', $lock_path
        or die "Unable to open Dropbox sync lock $lock_path: $!\n";
    flock $lock_handle, LOCK_EX
        or die "Unable to lock Dropbox sync lock $lock_path: $!\n";

    $state //= load_state($options->{job_state_file});
    die "Dropbox job state is unavailable: $options->{job_state_file}\n"
        if !defined $state->{job_path};
    my $paths = remote_paths($state);
    my $sync_state_path = $options->{checkpoint_dir} . '/.dropbox-sync-state.json';
    my $sync_state = load_state($sync_state_path);
    $sync_state->{files} //= {};

    for my $local_path (@{checkpoint_files($options->{checkpoint_dir})}) {
        my $name = basename($local_path);
        my $sha256 = file_sha256($local_path);
        next if ($sync_state->{files}{$local_path} // q{}) eq $sha256;
        my $timestamp = timestamp_utc();
        my $history_name = $name . '.' . $timestamp . '.' . substr($sha256, 0, 12) . '.json';
        my $sidecar_local = $local_path . '.sha256.sync';
        write_text_file_atomic($sidecar_local, $sha256 . '  ' . $name . "\n");

        upload_content($context, $local_path, $paths->{current} . '/' . $name, 'overwrite', 0);
        upload_content($context, $sidecar_local, $paths->{current} . '/' . $name . '.sha256', 'overwrite', 0);
        upload_content($context, $local_path, $paths->{history} . '/' . $history_name, 'add', 1);
        unlink $sidecar_local;

        $sync_state->{files}{$local_path} = $sha256;
        $sync_state->{last_checkpoint_sync_utc} = $timestamp;
        save_state($sync_state_path, $sync_state);
        print "Uploaded checkpoint: $name ($sha256)\n";
    }

    for my $local_path (@{output_files($options, $state)}) {
        my $size = -s $local_path;
        next if $size > $MAX_UPLOAD_BYTES;
        my $sha256 = file_sha256($local_path);
        next if ($sync_state->{files}{$local_path} // q{}) eq $sha256;
        my $name = basename($local_path);
        upload_content($context, $local_path, $paths->{outputs} . '/' . $name, 'overwrite', 0);
        $sync_state->{files}{$local_path} = $sha256;
        $sync_state->{last_output_sync_utc} = timestamp_utc();
        save_state($sync_state_path, $sync_state);
        print "Uploaded output/log: $name\n";
    }
    close $lock_handle or die "Unable to close Dropbox sync lock $lock_path: $!\n";
    return;
}

sub watch_job {
    my ($context, $options) = @_;
    die "--watch-pid must be a positive process ID.\n"
        if !defined $options->{watch_pid} || $options->{watch_pid} !~ /\A[1-9][0-9]*\z/;
    my $state = load_state($options->{job_state_file});
    while (kill 0, $options->{watch_pid}) {
        sync_once($context, $options, $state);
        sleep 15;
    }
    sync_once($context, $options, $state);
    return;
}

sub bootstrap_download {
    my ($context, $options) = @_;
    my $local_directory = $options->{local_directory};
    die "--local-directory is required.\n"
        if !defined $local_directory || !length $local_directory;
    make_path($local_directory);

    my $entries = list_folder($context, $options->{dropbox_root});
    my %remote_by_name;
    for my $entry (@{$entries}) {
        next if ($entry->{'.tag'} // q{}) ne 'file';
        $remote_by_name{$entry->{name}} = $entry;
    }

    my @runtime_manifests = sort grep {
        /\Awhisperx_transfer_bundle_[0-9]{8}(?:_[0-9]{6})?\.parts\.sha256\z/
    } keys %remote_by_name;
    die "No WhisperX dependency parts manifest exists under $options->{dropbox_root}.\n"
        if !@runtime_manifests;
    my $runtime_manifest_name = $runtime_manifests[-1];
    my $runtime_base = $runtime_manifest_name;
    $runtime_base =~ s/\.parts\.sha256\z//;
    my $archive_manifest_name = $runtime_base . '.tar.gz.sha256';
    die "Missing Dropbox archive manifest $archive_manifest_name.\n"
        if !exists $remote_by_name{$archive_manifest_name};

    my @source_manifests = sort grep {
        /\AwhisperX-fork_[0-9]{8}_[0-9]{6}\.tar\.gz\.sha256\z/
    } keys %remote_by_name;
    die "No timestamped WhisperX fork source manifest exists under $options->{dropbox_root}.\n"
        if !@source_manifests;
    my $source_manifest_name = $source_manifests[-1];
    my $source_archive_name = $source_manifest_name;
    $source_archive_name =~ s/\.sha256\z//;
    die "Missing Dropbox source archive $source_archive_name.\n"
        if !exists $remote_by_name{$source_archive_name};

    my @initial_names = (
        $runtime_manifest_name,
        $archive_manifest_name,
        $source_manifest_name,
        $source_archive_name,
    );
    for my $name (@initial_names) {
        my $remote_path = $remote_by_name{$name}->{path_display}
            // $remote_by_name{$name}->{path_lower};
        download_content($context, $remote_path, $local_directory . '/' . $name);
        print "Downloaded bootstrap file: $name\n";
    }

    my $parts_manifest_local = $local_directory . '/' . $runtime_manifest_name;
    open my $parts_handle, '<', $parts_manifest_local
        or die "Unable to read $parts_manifest_local: $!\n";
    while (my $line = <$parts_handle>) {
        chomp $line;
        my ($sha256, $manifest_path) = split /\s+/, $line, 2;
        next if !defined $manifest_path;
        my $name = basename($manifest_path);
        die "Missing Dropbox bundle part $name.\n" if !exists $remote_by_name{$name};
        my $local_part = $local_directory . '/' . $name;
        if (-f $local_part && file_sha256($local_part) eq $sha256) {
            print "Existing bundle part already verified: $name\n";
            next;
        }
        my $remote_path = $remote_by_name{$name}->{path_display}
            // $remote_by_name{$name}->{path_lower};
        download_content($context, $remote_path, $local_part);
        my $actual = file_sha256($local_part);
        die "Downloaded bundle part checksum mismatch for $name.\n"
            if $actual ne $sha256;
        print "Downloaded and verified bundle part: $name\n";
    }
    close $parts_handle or die "Unable to close $parts_manifest_local: $!\n";

    my @control_files = qw(
        whisperx_transfer_bundle_build.sh
        whisperx_dropbox_configure_credentials.pl
        whisperx_transfer_bundle_install_and_transcribe.sh
        whisperx_dropbox_restore_sandbox.sh
        whisperx_dropbox_checkpoint_sync.pl
        whisperx_dropbox_credentials.template.conf
        whisperx_sandbox_fail_safe_readme.md
        whisperx_transcribe_accents.sh
        whisperx_correct_transcript.pl
        whisperx_corrections.template.json
    );
    for my $name (@control_files) {
        next if !exists $remote_by_name{$name};
        my $remote_path = $remote_by_name{$name}->{path_display}
            // $remote_by_name{$name}->{path_lower};
        download_content($context, $remote_path, $local_directory . '/' . $name);
        chmod 0755, $local_directory . '/' . $name
            if $name =~ /\.(?:sh|pl)\z/;
        print "Downloaded control file: $name\n";
    }

    my $input_name = $options->{input_name} // q{};
    if (length $input_name) {
        die "Missing Dropbox input recording $input_name.\n"
            if !exists $remote_by_name{$input_name};
        my $remote_path = $remote_by_name{$input_name}->{path_display}
            // $remote_by_name{$input_name}->{path_lower};
        download_content($context, $remote_path, $local_directory . '/' . $input_name);
        print "Downloaded input recording: $input_name\n";
    }

    return;
}

sub parse_options {
    my ($arguments) = @_;
    my %options = (
        credentials_file => $ENV{WHISPERX_DROPBOX_CREDENTIALS_FILE} // q{},
        token_cache_file  => $ENV{WHISPERX_DROPBOX_TOKEN_CACHE_FILE} // q{},
        dropbox_root      => $ENV{WHISPERX_DROPBOX_ROOT} // $DEFAULT_DROPBOX_ROOT,
        source_version    => $ENV{WHISPERX_SOURCE_VERSION} // 'unknown',
        http_timeout      => $ENV{WHISPERX_DROPBOX_HTTP_TIMEOUT} // 120,
    );
    GetOptionsFromArray(
        $arguments,
        'credentials-file=s' => \$options{credentials_file},
        'token-cache-file=s'  => \$options{token_cache_file},
        'dropbox-root=s'      => \$options{dropbox_root},
        'input-file=s'        => \$options{input_file},
        'checkpoint-dir=s'    => \$options{checkpoint_dir},
        'run-log=s'           => \$options{run_log},
        'output-dir=s'        => \$options{output_dir},
        'job-state-file=s'    => \$options{job_state_file},
        'source-version=s'    => \$options{source_version},
        'watch-pid=i'         => \$options{watch_pid},
        'dropbox-path=s'      => \$options{dropbox_path},
        'local-path=s'        => \$options{local_path},
        'local-directory=s'   => \$options{local_directory},
        'input-name=s'        => \$options{input_name},
        'http-timeout=i'      => \$options{http_timeout},
    ) or usage();
    usage() if @{$arguments};
    return \%options;
}

my $command = shift @ARGV // q{};
usage() if $command !~ /\A(?:prepare|restore|sync-once|watch|download-file|bootstrap-download)\z/;
my $options = parse_options(\@ARGV);
if (!length($options->{token_cache_file} // q{})) {
    $options->{token_cache_file} = length($options->{credentials_file} // q{})
        ? $options->{credentials_file} . '.token-cache.json'
        : '/mnt/data/.whisperx-dropbox-token-cache.json';
}
die "--http-timeout must be a positive integer.\n"
    if $options->{http_timeout} !~ /\A[1-9][0-9]*\z/;
my $context = make_context(
    $options->{credentials_file},
    $options->{token_cache_file},
    $options->{http_timeout},
);

if ($command eq 'download-file') {
    die "--dropbox-path and --local-path are required.\n"
        if !defined $options->{dropbox_path} || !defined $options->{local_path};
    download_content($context, $options->{dropbox_path}, $options->{local_path});
    print "Downloaded Dropbox file: $options->{dropbox_path} -> $options->{local_path}\n";
    exit 0;
}

if ($command eq 'bootstrap-download') {
    bootstrap_download($context, $options);
    exit 0;
}

for my $required (qw(input_file checkpoint_dir job_state_file)) {
    die "--$required is required.\n" if !defined $options->{$required};
}

if ($command eq 'prepare') {
    my $state = prepare_job($context, $options);
    sync_once($context, $options, $state);
}
elsif ($command eq 'restore') {
    restore_checkpoints($context, $options);
}
elsif ($command eq 'sync-once') {
    sync_once($context, $options);
}
elsif ($command eq 'watch') {
    watch_job($context, $options);
}

exit 0;
