#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename qw(dirname);
use File::Path qw(make_path);
use Getopt::Long qw(GetOptions);
use HTTP::Tiny;
use JSON::PP qw(decode_json);
use MIME::Base64 qw(encode_base64);

our $VERSION = '0.001';

my $output_path = q{};
my $open_browser = 1;
GetOptions(
    'output=s'       => \$output_path,
    'open-browser!'  => \$open_browser,
) or die "Usage: $0 --output PATH [--no-open-browser]\n";
die "Usage: $0 --output PATH [--no-open-browser]\n" if !length $output_path;

die "Refusing to overwrite existing credentials file: $output_path\n"
    if -e $output_path;

sub percent_encode {
    my ($value) = @_;
    $value =~ s/([^A-Za-z0-9\-._~])/sprintf('%%%02X', ord($1))/eg;
    return $value;
}

sub prompt_value {
    my ($label, $hidden) = @_;
    print $label;
    if ($hidden && -t STDIN) {
        system('stty', '-echo') == 0
            or die "Unable to disable terminal echo.\n";
    }
    my $value = <STDIN>;
    if ($hidden && -t STDIN) {
        system('stty', 'echo') == 0
            or die "Unable to restore terminal echo.\n";
        print "\n";
    }
    die "No value was entered for $label\n" if !defined $value;
    chomp $value;
    $value =~ s/^\s+|\s+$//g;
    die "No value was entered for $label\n" if !length $value;
    die "Invalid newline in credential value.\n" if $value =~ /[\r\n]/;
    return $value;
}

my $app_key = $ENV{DROPBOX_APP_KEY} // q{};
my $app_secret = $ENV{DROPBOX_APP_SECRET} // q{};
$app_key = prompt_value('Dropbox app key: ', 0) if !length $app_key;
$app_secret = prompt_value('Dropbox app secret: ', 1) if !length $app_secret;

my $authorization_url = 'https://www.dropbox.com/oauth2/authorize'
    . '?client_id=' . percent_encode($app_key)
    . '&response_type=code'
    . '&token_access_type=offline';

print "\nOpen this Dropbox authorization URL in your browser:\n$authorization_url\n\n";
if ($open_browser && system('sh', '-c', 'command -v xdg-open >/dev/null 2>&1') == 0) {
    system('xdg-open', $authorization_url);
}

my $authorization_code = prompt_value('Paste the Dropbox authorization code: ', 1);
my $authorization = encode_base64($app_key . ':' . $app_secret, q{});
my $http = HTTP::Tiny->new(
    agent      => 'WhisperX-Dropbox-Credential-Setup/' . $VERSION,
    timeout    => 120,
    verify_SSL => 1,
);
my $response = $http->post(
    'https://api.dropboxapi.com/oauth2/token',
    {
        headers => {
            'Authorization' => 'Basic ' . $authorization,
            'Content-Type'  => 'application/x-www-form-urlencoded',
        },
        content => 'code=' . percent_encode($authorization_code)
            . '&grant_type=authorization_code',
    },
);
die "Dropbox authorization failed with HTTP $response->{status}: "
    . ($response->{content} // q{}) . "\n"
    if !$response->{success};

my $payload = decode_json($response->{content});
my $refresh_token = $payload->{refresh_token} // q{};
die "Dropbox did not return a refresh token. Confirm token_access_type=offline and try again.\n"
    if !length $refresh_token;

make_path(dirname($output_path));
my $temporary_path = $output_path . '.tmp.' . $$;
open my $file_handle, '>', $temporary_path
    or die "Unable to write $temporary_path: $!\n";
print {$file_handle} "# v0.001\n";
print {$file_handle} "# Private WhisperX Dropbox credentials. Never upload this file.\n";
print {$file_handle} "DROPBOX_APP_KEY=$app_key\n";
print {$file_handle} "DROPBOX_APP_SECRET=$app_secret\n";
print {$file_handle} "DROPBOX_REFRESH_TOKEN=$refresh_token\n";
print {$file_handle} "DROPBOX_ACCESS_TOKEN=\n";
close $file_handle or die "Unable to close $temporary_path: $!\n";
chmod 0600, $temporary_path
    or die "Unable to protect $temporary_path: $!\n";
rename $temporary_path, $output_path
    or die "Unable to replace $output_path with $temporary_path: $!\n";

print "Created private Dropbox credentials file: $output_path\n";
print "File mode: 0600\n";
print "Do not upload this file to Dropbox, Git, or ChatGPT.\n";
