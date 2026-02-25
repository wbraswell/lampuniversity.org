#!/usr/bin/bash
# chatgpt_markdown_fix_repo.sh v0.006_000

set -o pipefail
shopt -s nullglob

_usage() {
    cat <<'USAGE'
chatgpt_markdown_fix_repo.sh v0.006_000

Usage:
  chatgpt_markdown_fix_repo.sh [WRAPPER_OPTIONS] -- [FIXER_OPTIONS]

Wrapper options (must appear before "--"):
  --repo DIR
      Repo root to run in. Default: current directory.

  --inputs GLOB
      Input file glob (repeatable). Default: chat_history/*.md
      Note: files matching *__fixed.* are always excluded from inputs.

  --artifacts-dir DIR
      Directory to write run log and tarball. Default: /tmp

  --keep-artifacts
      Do not delete older chatgpt_markdown_fix__*.{log,tar.gz} files (and related lint logs) in artifacts-dir.

  --no-clean
      Skip the initial "--clean" pass.

  --lint
      Run repo markdown lint via: perl xt/author/02_markdown_lint.t
      Lint output is saved in artifacts-dir and included in the tarball.
      Note: lint auto-enables when fixer args include --markdownlint.

  --promote
      After fixing, lint only the produced '*__fixed.md' outputs, require '--verify', and if all checks pass, delete the original inputs.

  -h, --help
      Show this help.

Fixer options (must appear after "--"):
  All arguments after "--" are passed verbatim to chatgpt_markdown_fix.pl.

Examples:
  # Run in the current repo, using default inputs
  chatgpt_markdown_fix_repo.sh -- --debug --markdownlint

  # Run against a specific repo root
  chatgpt_markdown_fix_repo.sh --repo "$HOME/repos_gitlab/xedoc" -- --debug --markdownlint

  # Multiple input globs
  chatgpt_markdown_fix_repo.sh --inputs 'chat_history/*.md' --inputs 'docs/chat_history/*.md' -- --debug

USAGE
}

# Defaults
REPO_DIR=""
ARTIFACTS_DIR="/tmp"
KEEP_ARTIFACTS=0
DO_CLEAN=1
RUN_LINT=0
PROMOTE=0
INPUT_PATTERNS=()

# Parse wrapper options up to "--"
while (( $# )); do
    case "$1" in
        -h|--help)
            _usage
            exit 0
            ;;
        --repo)
            REPO_DIR="$2"
            shift 2
            ;;
        --repo=*)
            REPO_DIR="${1#--repo=}"
            shift
            ;;
        --inputs)
            INPUT_PATTERNS+=("$2")
            shift 2
            ;;
        --inputs=*)
            INPUT_PATTERNS+=("${1#--inputs=}")
            shift
            ;;
        --artifacts-dir)
            ARTIFACTS_DIR="$2"
            shift 2
            ;;
        --artifacts-dir=*)
            ARTIFACTS_DIR="${1#--artifacts-dir=}"
            shift
            ;;
        --keep-artifacts)
            KEEP_ARTIFACTS=1
            shift
            ;;
        --lint)
            RUN_LINT=1
            shift
            ;;
        --promote)
            PROMOTE=1
            shift
            ;;
        --no-clean)
            DO_CLEAN=0
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Unknown wrapper option (did you mean to put this after --?): $1" 1>&2
            _usage 1>&2
            exit 2
            ;;
    esac
done

FIXER_ARGS=("$@")

# Auto-enable lint evidence when fixer is running markdownlint repair passes.
for arg in "${FIXER_ARGS[@]}"; do
    if [[ "${arg}" == '--markdownlint' ]] || [[ "${arg}" == '--markdownlint='* ]]; then
        RUN_LINT=1
        break
    fi
done

# Enable command echoing after option parsing, so the log is readable.
set -x

# Decide repo root
if [[ -n "${REPO_DIR}" ]]; then
    cd "${REPO_DIR}" || exit 2
fi

# Default input patterns
if (( ${#INPUT_PATTERNS[@]} == 0 )); then
    INPUT_PATTERNS=('chat_history/*.md')
fi

# Locate fixer (default: sibling of this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXER="${CHATGPT_MARKDOWN_FIXER:-${SCRIPT_DIR}/chatgpt_markdown_fix.pl}"

if [[ ! -f "${FIXER}" ]]; then
    echo "Fixer not found: ${FIXER}" 1>&2
    echo "Set CHATGPT_MARKDOWN_FIXER or place chatgpt_markdown_fix.pl next to this script." 1>&2
    exit 2
fi

chmod a+x "${FIXER}"

# Build input file list
INPUT_FILES=()
declare -A _seen
for pattern in "${INPUT_PATTERNS[@]}"; do
    mapfile -t _matches < <(compgen -G "${pattern}" || true)
    for f in "${_matches[@]}"; do
        if [[ ! -f "${f}" ]]; then
            continue
        fi
        if [[ "${f}" == *__fixed.* ]]; then
            continue
        fi
        if [[ -n "${_seen[${f}]+x}" ]]; then
            continue
        fi
        _seen["${f}"]=1
        INPUT_FILES+=("${f}")
    done
done

if (( ${#INPUT_FILES[@]} == 0 )); then
    echo "No input files matched the provided patterns (excluding *__fixed.*) in $(pwd)" 1>&2
    exit 2
fi

# Create serialization tag
SERIAL="$(TZ=America/Chicago date '+%Y%m%d_%H%M%S')"

ARTIFACTS_DIR="${ARTIFACTS_DIR%/}"

mkdir -p "${ARTIFACTS_DIR}" || exit 2

RUN_LOG="${ARTIFACTS_DIR}/chatgpt_markdown_fix__${SERIAL}.log"
LINT_LOG="${ARTIFACTS_DIR}/chatgpt_markdown_lint__${SERIAL}.log"
TARBALL="${ARTIFACTS_DIR}/chatgpt_markdown_fix__${SERIAL}.tar.gz"

if (( KEEP_ARTIFACTS == 0 )); then
    rm -f "${ARTIFACTS_DIR}/chatgpt_markdown_fix__"*.tar.gz "${ARTIFACTS_DIR}/chatgpt_markdown_fix__"*.log "${ARTIFACTS_DIR}/chatgpt_markdown_lint__"*.log
fi

: > "${RUN_LOG}"

echo "[[[ STARTING... ]]]" | tee -a "${RUN_LOG}"
echo "PWD: $(pwd)" | tee -a "${RUN_LOG}"
echo "FIXER: ${FIXER}" | tee -a "${RUN_LOG}"
echo "INPUT_PATTERNS: ${INPUT_PATTERNS[*]}" | tee -a "${RUN_LOG}"
echo "INPUT_COUNT: ${#INPUT_FILES[@]}" | tee -a "${RUN_LOG}"
echo "RUN_LINT: ${RUN_LINT}" | tee -a "${RUN_LOG}"
echo "PROMOTE: ${PROMOTE}" | tee -a "${RUN_LOG}"
# Promotion mode requires verification and forbids --dry-run.
if (( PROMOTE == 1 )); then
    RUN_LINT=1
    for arg in "${FIXER_ARGS[@]}"; do
        if [[ "${arg}" == '--dry-run' ]] || [[ "${arg}" == '--dry-run='* ]]; then
            echo "PROMOTE requires real outputs; refusing to run with --dry-run" | tee -a "${RUN_LOG}"
            exit 2
        fi
    done

    _has_verify=0
    for arg in "${FIXER_ARGS[@]}"; do
        if [[ "${arg}" == '--verify' ]] || [[ "${arg}" == '--verify='* ]]; then
            _has_verify=1
            break
        fi
    done
    if (( _has_verify == 0 )); then
        echo "PROMOTE: adding --verify to fixer args" | tee -a "${RUN_LOG}"
        FIXER_ARGS+=('--verify')
    fi
fi


CLEAN_EXIT=0
if (( DO_CLEAN == 1 )); then
    echo "[[[ CLEANING... ]]]" | tee -a "${RUN_LOG}"
    "${FIXER}" --clean "${FIXER_ARGS[@]}" "${INPUT_FILES[@]}" >> "${RUN_LOG}" 2>&1
    CLEAN_EXIT=$?
    if (( CLEAN_EXIT != 0 )); then
        echo "Clean step failed with exit code ${CLEAN_EXIT}" 1>&2
        echo "LOG: ${RUN_LOG}" 1>&2
        exit "${CLEAN_EXIT}"
    fi
fi

echo "[[[ FIXING... ]]]" | tee -a "${RUN_LOG}"
"${FIXER}" "${FIXER_ARGS[@]}" "${INPUT_FILES[@]}" >> "${RUN_LOG}" 2>&1
FIXER_EXIT=$?
LINT_EXIT=0
FIXED_FILES=()
FIXED_DEBUG_FILES=()

# Determine expected fixed outputs for linting and promotion
for in_f in "${INPUT_FILES[@]}"; do
    if [[ "${in_f}" == *.* ]]; then
        out_f="${in_f%.*}__fixed.${in_f##*.}"
    else
        out_f="${in_f}__fixed"
    fi
    dbg_f="${in_f%.*}__fixed.debug"

    if [[ -f "${out_f}" ]]; then
        FIXED_FILES+=("${out_f}")
    fi
    if [[ -f "${dbg_f}" ]]; then
        FIXED_DEBUG_FILES+=("${dbg_f}")
    fi
done

if (( RUN_LINT == 1 )); then
    : > "${LINT_LOG}"

    if [[ -f 'xt/author/02_markdown_lint.t' ]]; then
        echo "[[[ LINTING (xt/author/02_markdown_lint.t)... ]]]" | tee -a "${RUN_LOG}"

        {
            echo "FIXER_EXIT=${FIXER_EXIT}"
            echo "PWD=$(pwd)"
            echo ""
            perl xt/author/02_markdown_lint.t
        } > "${LINT_LOG}" 2>&1
        LINT_EXIT=$?
    else
        echo "[[[ LINTING FAILED (missing xt/author/02_markdown_lint.t) ]]]" | tee -a "${RUN_LOG}"
        echo 'Missing xt/author/02_markdown_lint.t; cannot lint' >> "${LINT_LOG}"
        LINT_EXIT=2
    fi

    echo "LINT_LOG: ${LINT_LOG}" | tee -a "${RUN_LOG}"
    echo "LINT_EXIT: ${LINT_EXIT}" | tee -a "${RUN_LOG}"
fi

# Package inputs, outputs, and helper files for analysis
TAR_FILES=(
    "${RUN_LOG}"
    "${FIXER}"
    "$(realpath "$0")"
)

if [[ -f "${LINT_LOG}" ]]; then
    TAR_FILES+=("${LINT_LOG}")
fi

# Include optional helper files next to the fixer (for example: chatgpt_good.md, chatgpt_bad.md)
for extra in "${SCRIPT_DIR}/chatgpt_good.md" "${SCRIPT_DIR}/chatgpt_bad.md"; do
    if [[ -f "${extra}" ]]; then
        TAR_FILES+=("${extra}")
    fi
done

# Include each input and its produced outputs (if present)
for in_f in "${INPUT_FILES[@]}"; do
    TAR_FILES+=("$(realpath "${in_f}")")
done

for out_f in "${FIXED_FILES[@]}"; do
    if [[ -f "${out_f}" ]]; then
        TAR_FILES+=("$(realpath "${out_f}")")
    fi
done

for dbg_f in "${FIXED_DEBUG_FILES[@]}"; do
    if [[ -f "${dbg_f}" ]]; then
        TAR_FILES+=("$(realpath "${dbg_f}")")
    fi
done

echo "[[[ TARRING... ]]]" | tee -a "${RUN_LOG}"
tar -czf "${TARBALL}" "${TAR_FILES[@]}"
TAR_EXIT=$?
echo "TAR_EXIT: ${TAR_EXIT}" | tee -a "${RUN_LOG}"
PROMOTE_EXIT=0
if (( PROMOTE == 1 )); then
    if (( FIXER_EXIT == 0 && LINT_EXIT == 0 && TAR_EXIT == 0 )); then
        echo "[[[ PROMOTING (DELETING ORIGINAL INPUTS)... ]]]" | tee -a "${RUN_LOG}"
        for in_f in "${INPUT_FILES[@]}"; do
            # Only delete if the expected fixed output exists
            if [[ "${in_f}" == *.* ]]; then
                out_f="${in_f%.*}__fixed.${in_f##*.}"
            else
                out_f="${in_f}__fixed"
            fi

            if [[ ! -f "${out_f}" ]]; then
                echo "PROMOTE: missing fixed output, refusing to delete: ${in_f}" | tee -a "${RUN_LOG}"
                PROMOTE_EXIT=2
                continue
            fi

            if [[ -L "${in_f}" ]]; then
                echo "PROMOTE: refusing to delete symlink input: ${in_f}" | tee -a "${RUN_LOG}"
                PROMOTE_EXIT=2
                continue
            fi

            rm -f "${in_f}"
            if [[ -f "${in_f}" ]]; then
                echo "PROMOTE: failed to delete: ${in_f}" | tee -a "${RUN_LOG}"
                PROMOTE_EXIT=2
            else
                echo "PROMOTE: deleted: ${in_f}" | tee -a "${RUN_LOG}"
            fi
        done
    else
        echo "[[[ PROMOTING SKIPPED (checks failed) ]]]" | tee -a "${RUN_LOG}"
        echo "FIXER_EXIT=${FIXER_EXIT} LINT_EXIT=${LINT_EXIT} TAR_EXIT=${TAR_EXIT}" | tee -a "${RUN_LOG}"
    fi
fi

echo "TARBALL: ${TARBALL}" | tee -a "${RUN_LOG}"
echo "LOG: ${RUN_LOG}" | tee -a "${RUN_LOG}"
if [[ -f "${LINT_LOG}" ]]; then
    echo "LINT_LOG: ${LINT_LOG}" | tee -a "${RUN_LOG}"
fi

EXIT_CODE=0
if (( FIXER_EXIT != 0 )); then
    EXIT_CODE="${FIXER_EXIT}"
fi
if (( LINT_EXIT != 0 )); then
    if (( EXIT_CODE == 0 )); then
        EXIT_CODE="${LINT_EXIT}"
    fi
fi
if (( TAR_EXIT != 0 )); then
    echo "Tar step failed with exit code ${TAR_EXIT}" 1>&2
    if (( EXIT_CODE == 0 )); then
        EXIT_CODE="${TAR_EXIT}"
    fi
fi
if (( PROMOTE_EXIT != 0 )); then
    if (( EXIT_CODE == 0 )); then
        EXIT_CODE="${PROMOTE_EXIT}"
    fi
fi

exit "${EXIT_CODE}"

