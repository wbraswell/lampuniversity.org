# WhisperX Sandbox Fail-Safe Workflow

Document version: 0.003

## Purpose

This workflow protects expensive WhisperX transcription progress against complete ChatGPT sandbox loss without using a custom Dropbox Developer App, direct Dropbox HTTP API access, OAuth credentials, or direct sandbox networking.

The design separates two kinds of state:

- Small, changing transcription checkpoints are persisted through the ChatGPT Dropbox connector as compact JSON deltas.
- Large, mostly static binary inputs such as the runtime bundle, WhisperX source archive, and meeting recording are staged into a sandbox separately. The current recovery bridge under test uses a GitHub Actions artifact relay so those binaries are never committed to Git.

WhisperX itself does not make Dropbox API calls and does not need Dropbox credentials.

## Active control files

The active control path consists of:

```text
bin/whisperx_checkpoint_connector_pause.sh
bin/whisperx_checkpoint_connector_restore.sh
bin/whisperx_restore_sandbox.sh
bin/whisperx_sandbox_fail_safe_readme.md
bin/whisperx_transcribe_accents.sh
bin/whisperx_transfer_bundle_build.sh
bin/whisperx_transfer_bundle_install_and_transcribe.sh
.github/workflows/whisperx-sandbox-relay.yml
```

The former custom Dropbox-App/API synchronization helpers, credential configurator/template, and Dropbox-named restore launcher are obsolete and are not part of the active workflow. The current restore launcher is `bin/whisperx_restore_sandbox.sh` and performs no Dropbox API access.

## Build outputs

Run the bundler in one of three modes:

```bash
~/repos_github/lampuniversity.org/bin/whisperx_transfer_bundle_build.sh source
~/repos_github/lampuniversity.org/bin/whisperx_transfer_bundle_build.sh dependencies
~/repos_github/lampuniversity.org/bin/whisperx_transfer_bundle_build.sh all
```

`source` creates the independently replaceable WhisperX fork archive and checksum:

```text
whisperX-fork_YYYYMMDD_HHMMSS.tar.gz
whisperX-fork_YYYYMMDD_HHMMSS.tar.gz.sha256
whisperx_build_set_YYYYMMDD_HHMMSS.manifest.txt
```

`dependencies` creates the large source-independent runtime bundle:

```text
whisperx_transfer_bundle_YYYYMMDD_HHMMSS.tar.gz.part-000...
whisperx_transfer_bundle_YYYYMMDD_HHMMSS.parts.sha256
whisperx_transfer_bundle_YYYYMMDD_HHMMSS.tar.gz.sha256
whisperx_build_set_YYYYMMDD_HHMMSS.manifest.txt
```

The runtime bundle and source archive remain separate so source-only changes do not require rebuilding the multi-gigabyte dependency bundle.

## Ordinary Dropbox storage layout

The ChatGPT Dropbox connector uses the normal Dropbox folder:

```text
/home_wbraswell/school/utd/whisperx/
```

There is no special Dropbox application-folder dependency.

Durable transcription deltas are written under:

```text
/home_wbraswell/school/utd/whisperx/jobs/<job-id>/checkpoints/
    transcription-partial-000001.json
    transcription-partial-000002.json
    transcription-partial-000003.json
    ...
```

The default `<job-id>` is the recording filename stem unless `WHISPERX_CONNECTOR_JOB_ID` explicitly overrides it.

## Checkpoint handoff

WhisperX first writes its cumulative local `transcription-partial` checkpoint atomically. Its synchronous checkpoint hook then runs `whisperx_checkpoint_connector_pause.sh`.

For each newly completed transcription chunk, the hook:

1. Reads the cumulative local checkpoint.
2. Extracts only the newest completed segment plus recording identity and source metadata into a compact JSON delta.
3. Writes that delta into the local connector outbox.
4. Writes `pending.env` containing the intended ordinary Dropbox destination path, local size, SHA-256, segment count, and ACK path.
5. Blocks the same WhisperX process until the ChatGPT tool layer uploads the delta through the Dropbox connector and writes a matching local ACK.
6. Returns only after validating the ACK, allowing the already-loaded WhisperX process to continue with the next chunk.

This is intentionally synchronous. WhisperX must not advance past a completed transcription chunk until that chunk has been durably acknowledged by the connector workflow.

Completed non-transcription stages remain local. After a total sandbox loss, the protected transcription deltas are sufficient to reconstruct transcription progress; alignment and diarization can be rerun without retranscribing the protected chunks.

## No custom Dropbox credentials

Do not create or configure a custom Dropbox application for this workflow. Do not add Dropbox application keys, secrets, access tokens, refresh tokens, private credential files, or direct Dropbox HTTP API calls to the active scripts.

References to the **ChatGPT Dropbox connector** in the active scripts are intentional. Dropbox remains the durable checkpoint store; only the old custom application/API/OAuth mechanism has been removed.

## Large binary sandbox recovery

The ChatGPT Dropbox connector can read and write the small checkpoint JSON files, but the current tool boundary does not directly place large Dropbox binary files into `/mnt/data`.

The current recovery strategy uses `.github/workflows/whisperx-sandbox-relay.yml` as a binary relay:

```text
ordinary Dropbox public download link
    -> GitHub-hosted Actions runner temporary disk
    -> GitHub Actions artifact storage
    -> ChatGPT GitHub connector
    -> reconstructed sandbox
```

Only the small workflow YAML file is committed to Git. Runtime bundle parts, source archives, recordings, and other large binaries are never committed to Git history by this relay.

The relay artifact should use short retention and can be discarded after successful sandbox staging. This relay must be validated end-to-end before it is treated as production-ready recovery infrastructure.

## Recovery after a complete sandbox reset

A deleted sandbox cannot execute its own recovery. The ChatGPT tool layer must first reconstruct the required files in `/mnt/data`.

The intended recovery order is:

1. Stage the required runtime bundle parts and manifests through the validated large-binary relay.
2. Stage the latest WhisperX source archive and checksum through the same relay.
3. Stage the meeting recording through the same relay.
4. Stage the active control scripts.
5. Fetch the available checkpoint delta JSON files from the ordinary Dropbox `jobs/<job-id>/checkpoints/` directory through the ChatGPT Dropbox connector.
6. Place those delta files into a local restored-delta directory.
7. Run `whisperx_checkpoint_connector_restore.sh` to verify recording identity, contiguous segment numbering, source version, language, size, and SHA-256, then reconstruct the canonical cumulative `transcription-partial` checkpoint.
8. Run the installer/launcher with automatic checkpoint resume.

`whisperx_restore_sandbox.sh` deliberately performs no network access. It verifies that the tool layer already staged the installer, wrapper, connector helpers, and recording, runs both connector-helper preflights, and then invokes the installer.

## Preparation-only validation

Before starting an expensive transcription, use preparation-only mode to validate the staged runtime and control path without starting WhisperX transcription:

```bash
WHISPERX_PREPARE_ONLY=1 /mnt/data/whisperx_restore_sandbox.sh 2026-08-04_14-02-32.mp4 3
```

The installer and wrapper must report successful preparation and explicitly state that transcription was not started.

Do not begin the production WhisperX run until the complete checkpoint persistence and sandbox recovery path has been confirmed ready.

## Resume granularity

Transcription resumes per completed VAD/transcription chunk from the reconstructed cumulative partial checkpoint. Alignment and diarization resume at whole-stage granularity; interruption during either stage can require rerunning that stage, but protected transcription chunks do not need to be retranscribed.
