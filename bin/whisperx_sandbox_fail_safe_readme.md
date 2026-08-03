# WhisperX Sandbox Fail-Safe Workflow

Document version: 0.001

## Purpose

This update keeps the large dependency/runtime bundle independent from the frequently changing WhisperX fork and makes every incremental checkpoint durable in Dropbox before transcription advances.

## Build outputs

Run the updated bundler in one of three modes:

```bash
~/Downloads/build_whisperx_transfer_bundle.sh source
~/Downloads/build_whisperx_transfer_bundle.sh dependencies
~/Downloads/build_whisperx_transfer_bundle.sh all
```

`source` creates only:

```text
whisperX-fork_YYYYMMDD_HHMMSS.tar.gz
whisperX-fork_YYYYMMDD_HHMMSS.tar.gz.sha256
whisperx_build_set_YYYYMMDD_HHMMSS.manifest.txt
```

`dependencies` creates only the large, source-independent runtime bundle:

```text
whisperx_transfer_bundle_YYYYMMDD_HHMMSS.tar.gz.part-000...
whisperx_transfer_bundle_YYYYMMDD_HHMMSS.parts.sha256
whisperx_transfer_bundle_YYYYMMDD_HHMMSS.tar.gz.sha256
whisperx_build_set_YYYYMMDD_HHMMSS.manifest.txt
```

The currently uploaded date-only dependency bundle remains usable. Rebuilding the large dependency bundle is unnecessary for this source/checkpoint upgrade.

## Dropbox job layout

Each recording receives a stable job directory based on its filename stem and full audio SHA-256:

```text
/home_wbraswell/school/utd/whisperx/jobs/
    2026-04-22_14-01-00__<first-16-sha256>/
        job-manifest.json
        checkpoints/
            current/
                *.whisperx-*.json
                *.whisperx-*.json.sha256
            history/
                <versioned-checkpoint-files>
        outputs/
            run log and completed transcript files
```

A checkpoint is first atomically replaced locally, then synchronously uploaded to Dropbox. WhisperX does not report the chunk as complete or continue to the next chunk when the Dropbox upload fails.

## Credentials

An unattended shell cannot invoke the ChatGPT Dropbox connector. The wrapper therefore uses the Dropbox HTTP API directly. Credentials are never embedded in the fork, bundle, control tarball, job manifest, or checkpoint files.

Create a Dropbox app with access to the required folder and the file metadata/content read and write permissions. Then run:

```bash
chmod a+x configure_whisperx_dropbox_credentials.pl
./configure_whisperx_dropbox_credentials.pl \
    --output /private/path/whisperx_dropbox_credentials.conf
```

Protect and export the private file:

```bash
chmod 0600 /private/path/whisperx_dropbox_credentials.conf
export WHISPERX_DROPBOX_CREDENTIALS_FILE=/private/path/whisperx_dropbox_credentials.conf
```

Never upload that credential file to Dropbox, Git, or ChatGPT.

## First sandbox installation and run

Place the dependency bundle files, latest source archive and checksum, control scripts, MP4, and private credential file in the sandbox. Then run:

```bash
chmod a+x /mnt/data/install_whisperx_transfer_bundle_and_transcribe.sh
/mnt/data/install_whisperx_transfer_bundle_and_transcribe.sh \
    /mnt/data/2026-04-22_14-01-00.mp4 \
    3
```

The wrapper automatically:

1. Hashes the recording and chooses its stable Dropbox job directory.
2. Restores the latest current checkpoints and verifies their SHA-256 sidecars.
3. Starts WhisperX with `--resume_from auto`.
4. Uploads every new partial or completed-stage checkpoint synchronously.
5. Mirrors the changing run log and final output files in the background.
6. Stops WhisperX rather than allowing unsynchronized progress when checkpoint synchronization fails.

## Recovery after a sandbox reset

A deleted sandbox cannot execute its own recovery. Reintroduce only these bootstrap requirements:

```text
restore_whisperx_sandbox_from_dropbox.sh
whisperx_dropbox_checkpoint_sync.pl
private Dropbox credentials file or equivalent environment variables
```

Then run:

```bash
chmod a+x /mnt/data/restore_whisperx_sandbox_from_dropbox.sh
/mnt/data/restore_whisperx_sandbox_from_dropbox.sh \
    2026-04-22_14-01-00.mp4 \
    3
```

The restore script downloads the newest compatible dependency manifests/parts, newest timestamped source archive, control scripts, and MP4. The installer recreates the runtime. The wrapper restores the checkpoint set and resumes from the first unfinished transcription chunk or latest completed whole stage.

## Remaining stage granularity

Transcription resumes per VAD chunk. Alignment and diarization resume from completed whole-stage checkpoints; an interruption partway through either of those stages restarts only that stage, not transcription.
