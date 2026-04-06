#!/usr/bin/bash
# chatgpt_markdown_fix_repo.sh v0.018

set -o pipefail
shopt -s nullglob

SCRIPT_BANNER="$(sed -n '2s/^# //p' "${BASH_SOURCE[0]}")"
if [[ -z "${SCRIPT_BANNER}" ]]; then
    SCRIPT_BANNER='chatgpt_markdown_fix_repo.sh'
fi


_usage() {
    printf '%s\n\n' "${SCRIPT_BANNER}"
    cat <<'USAGE'
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

  --output-dir DIR
      Write produced '*__fixed.*' outputs under DIR while preserving input-relative paths.

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

  --self-check
      Run the built-in regression fixtures before processing inputs.
      If used without --repo and --inputs, run the self-check only and exit.

      Self-check comparisons can ignore intentionally-different lines.
      Use this marker comment on its own line:
          <!-- no-compare-next-line -->
      The marker line and the immediately following line are excluded from comparisons.

  Automatic verifier preflight
      When fixer args include --verify, this wrapper first runs
      'chatgpt_markdown_fix.pl --verify-self-check' and aborts early on failure.

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

_self_check_strip_no_compare() {
    awk '
        (skip_next == 1) { skip_next = 0; next; }
        (/^[[:space:]]*<!--[[:space:]]*no-compare-next-line[[:space:]]*-->[[:space:]]*$/) { skip_next = 1; next; }
        (/^##[[:space:]]+no[[:space:]]+compare[[:space:]]/) { next; }
        { print; }
    '
}

compute_fixed_output_path() {
    local in_f="$1"
    local output_dir="$2"
    local out_f=''
    local rel_f=''

    if [[ "${in_f}" == *.* ]]; then
        out_f="${in_f%.*}__fixed.${in_f##*.}"
    else
        out_f="${in_f}__fixed"
    fi

    if [[ -z "${output_dir}" ]]; then
        printf '%s\n' "${out_f}"
        return 0
    fi

    rel_f="${in_f#./}"
    while [[ "${rel_f}" == /* ]]; do
        rel_f="${rel_f#/}"
    done

    if [[ "${rel_f}" == *.* ]]; then
        out_f="${rel_f%.*}__fixed.${rel_f##*.}"
    else
        out_f="${rel_f}__fixed"
    fi

    printf '%s\n' "${output_dir%/}/${out_f}"
}

compute_debug_output_path() {
    local fixed_f="$1"
    local dbg_f="${fixed_f}"

    dbg_f="${dbg_f%.*}.debug"
    if [[ "${dbg_f}" == "${fixed_f}" ]]; then
        dbg_f="${fixed_f}.debug"
    fi

    printf '%s\n' "${dbg_f}"
}

# Defaults
REPO_DIR=""
REPO_DIR_SET=0
INPUTS_SET=0
ARTIFACTS_DIR="/tmp"
OUTPUT_DIR=""
KEEP_ARTIFACTS=0
DO_CLEAN=1
RUN_LINT=0
PROMOTE=0
SELF_CHECK=0
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
            REPO_DIR_SET=1
            shift 2
            ;;
        --repo=*)
            REPO_DIR="${1#--repo=}"
            REPO_DIR_SET=1
            shift
            ;;
        --inputs)
            INPUT_PATTERNS+=("$2")
            INPUTS_SET=1
            shift 2
            ;;
        --inputs=*)
            INPUT_PATTERNS+=("${1#--inputs=}")
            INPUTS_SET=1
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
        --output-dir)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --output-dir=*)
            OUTPUT_DIR="${1#--output-dir=}"
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
        --self-check)
            SELF_CHECK=1
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

SELF_CHECK_ONLY=0
if (( SELF_CHECK == 1 && REPO_DIR_SET == 0 && INPUTS_SET == 0 )); then
    SELF_CHECK_ONLY=1
fi

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
if (( SELF_CHECK_ONLY == 0 )); then
    if [[ -n "${REPO_DIR}" ]]; then
        cd "${REPO_DIR}" || exit 2
    fi
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

# Create serialization tag
SERIAL="$(TZ=America/Chicago date '+%Y%m%d_%H%M%S')"

ARTIFACTS_DIR="${ARTIFACTS_DIR%/}"

mkdir -p "${ARTIFACTS_DIR}" || exit 2

RUN_LOG="${ARTIFACTS_DIR}/chatgpt_markdown_fix__${SERIAL}.log"
LINT_LOG="${ARTIFACTS_DIR}/chatgpt_markdown_lint__${SERIAL}.log"
TARBALL="${ARTIFACTS_DIR}/chatgpt_markdown_fix__${SERIAL}.tar.gz"

if (( KEEP_ARTIFACTS == 0 )); then
    rm -f "${ARTIFACTS_DIR}/chatgpt_markdown_fix__"*.tar.gz "${ARTIFACTS_DIR}/chatgpt_markdown_fix__"*.log "${ARTIFACTS_DIR}/chatgpt_markdown_lint__"*.log
    rm -rf "${ARTIFACTS_DIR}/chatgpt_markdown_self_check__"*
fi

: > "${RUN_LOG}"

RUN_FIXER_ARGS=("${FIXER_ARGS[@]}")
if (( SELF_CHECK_ONLY == 0 )) && [[ -n "${OUTPUT_DIR}" ]]; then
    RUN_FIXER_ARGS+=(--output-dir "${OUTPUT_DIR}")
fi

VERIFY_PRECHECK=0
for arg in "${FIXER_ARGS[@]}"; do
    if [[ "${arg}" == '--verify' ]] || [[ "${arg}" == '--verify='* ]]; then
        VERIFY_PRECHECK=1
        break
    fi
done

SELF_DIR=""
SELF_DIFF=""

if (( SELF_CHECK == 1 )); then
    echo "[[[ STARTING SELF-CHECK... ]]]" | tee -a "${RUN_LOG}"
    echo "PWD: $(pwd)" | tee -a "${RUN_LOG}"
    echo "FIXER: ${FIXER}" | tee -a "${RUN_LOG}"
    echo "FIXER_ARGS: ${FIXER_ARGS[*]}" | tee -a "${RUN_LOG}"

    SELF_FIXER_ARGS=("${FIXER_ARGS[@]}")
    echo "ARTIFACTS_DIR: ${ARTIFACTS_DIR}" | tee -a "${RUN_LOG}"

    # Self-check requires verification and forbids --dry-run.
    for arg in "${SELF_FIXER_ARGS[@]}"; do
        if [[ "${arg}" == '--dry-run' ]] || [[ "${arg}" == '--dry-run='* ]]; then
            echo 'SELF-CHECK requires real outputs; refusing to run with --dry-run' | tee -a "${RUN_LOG}"
            exit 2
        fi
    done

    _has_verify=0
    _has_markdownlint=0
    for arg in "${FIXER_ARGS[@]}"; do
        if [[ "${arg}" == '--verify' ]] || [[ "${arg}" == '--verify='* ]]; then
            _has_verify=1
        fi
        if [[ "${arg}" == '--markdownlint' ]] || [[ "${arg}" == '--markdownlint='* ]]; then
            _has_markdownlint=1
        fi
        if (( _has_verify == 1 && _has_markdownlint == 1 )); then
            break
        fi
    done

    if (( _has_verify == 0 )); then
        echo 'SELF-CHECK: adding --verify to self-check fixer args' | tee -a "${RUN_LOG}"
        SELF_FIXER_ARGS+=('--verify')
    fi

    if (( _has_markdownlint == 0 )); then
        echo 'SELF-CHECK: adding --markdownlint to self-check fixer args' | tee -a "${RUN_LOG}"
        SELF_FIXER_ARGS+=('--markdownlint')
    fi

    GOOD_SRC="${SCRIPT_DIR}/chatgpt_good.md"
    BAD_SRC="${SCRIPT_DIR}/chatgpt_bad.md"

    echo "SELF_FIXER_ARGS: ${SELF_FIXER_ARGS[*]}" | tee -a "${RUN_LOG}"

    if [[ ! -f "${GOOD_SRC}" ]]; then
        echo "Self-check fixture missing: ${GOOD_SRC}" | tee -a "${RUN_LOG}"
        exit 2
    fi

    if [[ ! -f "${BAD_SRC}" ]]; then
        echo "Self-check fixture missing: ${BAD_SRC}" | tee -a "${RUN_LOG}"
        exit 2
    fi

    SELF_DIR="${ARTIFACTS_DIR}/chatgpt_markdown_self_check__${SERIAL}"
    mkdir -p "${SELF_DIR}" || exit 2

    cp -f "${GOOD_SRC}" "${SELF_DIR}/chatgpt_good.md"
    cp -f "${BAD_SRC}" "${SELF_DIR}/chatgpt_bad.md"

    echo "[[[ SELF-CHECK FIXING... ]]]" | tee -a "${RUN_LOG}"
    "${FIXER}" "${SELF_FIXER_ARGS[@]}" "${SELF_DIR}/chatgpt_good.md" "${SELF_DIR}/chatgpt_bad.md" >> "${RUN_LOG}" 2>&1
    SELF_FIXER_EXIT=$?
    echo "SELF_FIXER_EXIT: ${SELF_FIXER_EXIT}" | tee -a "${RUN_LOG}"

    GOOD_FIXED="${SELF_DIR}/chatgpt_good__fixed.md"
    BAD_FIXED="${SELF_DIR}/chatgpt_bad__fixed.md"

    SELF_DIFF="${ARTIFACTS_DIR}/chatgpt_markdown_self_check__${SERIAL}.diff"
    : > "${SELF_DIFF}"

    SELF_EXIT=0
    if (( SELF_FIXER_EXIT != 0 )); then
        echo 'SELF-CHECK: fixer failed' | tee -a "${RUN_LOG}"
        SELF_EXIT="${SELF_FIXER_EXIT}"
    fi

    if [[ ! -f "${GOOD_FIXED}" ]]; then
        echo "SELF-CHECK FAIL: missing output: ${GOOD_FIXED}" | tee -a "${RUN_LOG}"
        SELF_EXIT=2
    fi

    if [[ ! -f "${BAD_FIXED}" ]]; then
        echo "SELF-CHECK FAIL: missing output: ${BAD_FIXED}" | tee -a "${RUN_LOG}"
        SELF_EXIT=2
    fi

    if [[ -f "${GOOD_FIXED}" ]]; then
        GOOD_IDEMP_SRC="${SELF_DIR}/chatgpt_good__idempotent_src.md"
        GOOD_IDEMP_FIXED="${SELF_DIR}/chatgpt_good__idempotent_fixed.md"

        _self_check_strip_no_compare < "${SELF_DIR}/chatgpt_good.md" > "${GOOD_IDEMP_SRC}"
        _self_check_strip_no_compare < "${GOOD_FIXED}" > "${GOOD_IDEMP_FIXED}"

        if ! cmp -s "${GOOD_IDEMP_SRC}" "${GOOD_IDEMP_FIXED}"; then
            echo 'SELF-CHECK FAIL: good changed (not idempotent)' | tee -a "${RUN_LOG}"
            diff -u "${GOOD_IDEMP_SRC}" "${GOOD_IDEMP_FIXED}" >> "${SELF_DIFF}" 2>&1 || true
            SELF_EXIT=2
        else
            echo 'SELF-CHECK OK: good is idempotent' | tee -a "${RUN_LOG}"
        fi
    fi

    if [[ -f "${BAD_FIXED}" ]]; then
        GOOD_CMP="${SELF_DIR}/chatgpt_good__compare.md"
        BAD_CMP="${SELF_DIR}/chatgpt_bad__fixed__compare.md"

        _self_check_strip_no_compare < "${SELF_DIR}/chatgpt_good.md" > "${GOOD_CMP}"
        _self_check_strip_no_compare < "${BAD_FIXED}" > "${BAD_CMP}"

        if ! cmp -s "${GOOD_CMP}" "${BAD_CMP}"; then
            echo 'SELF-CHECK FAIL: bad fixed does not match good' | tee -a "${RUN_LOG}"
            diff -u "${GOOD_CMP}" "${BAD_CMP}" >> "${SELF_DIFF}" 2>&1 || true
            SELF_EXIT=2
        else
            echo 'SELF-CHECK OK: bad fixed matches good' | tee -a "${RUN_LOG}"
        fi
    fi

    if [[ -s "${SELF_DIFF}" ]]; then
        echo "SELF_DIFF: ${SELF_DIFF}" | tee -a "${RUN_LOG}"
    else
        rm -f "${SELF_DIFF}"
    fi

    NEED_SELF_TAR=0
    if (( SELF_CHECK_ONLY == 1 )); then
        NEED_SELF_TAR=1
    fi
    if (( SELF_EXIT != 0 )); then
        NEED_SELF_TAR=1
    fi

    TAR_EXIT=0
    if (( NEED_SELF_TAR == 1 )); then
        echo "[[[ SELF-CHECK TARRING... ]]]" | tee -a "${RUN_LOG}"

        TAR_FILES=(
            "${RUN_LOG}"
            "${FIXER}"
            "$(realpath "$0")"
            "${GOOD_SRC}"
            "${BAD_SRC}"
        )

        for f in "${SELF_DIR}/chatgpt_good.md" "${SELF_DIR}/chatgpt_bad.md" "${GOOD_FIXED}" "${BAD_FIXED}"; do
            if [[ -f "${f}" ]]; then
                TAR_FILES+=("$(realpath "${f}")")
            fi
        done

        for f in "${SELF_DIR}/chatgpt_good__fixed.debug" "${SELF_DIR}/chatgpt_bad__fixed.debug"; do
            if [[ -f "${f}" ]]; then
                TAR_FILES+=("$(realpath "${f}")")
            fi
        done

        if [[ -f "${SELF_DIFF}" ]]; then
            TAR_FILES+=("$(realpath "${SELF_DIFF}")")
        fi

        tar -czf "${TARBALL}" "${TAR_FILES[@]}"
        TAR_EXIT=$?
        echo "TAR_EXIT: ${TAR_EXIT}" | tee -a "${RUN_LOG}"
        echo "TARBALL: ${TARBALL}" | tee -a "${RUN_LOG}"
    fi

    EXIT_CODE=0
    if (( SELF_EXIT != 0 )); then
        EXIT_CODE="${SELF_EXIT}"
    fi

    if (( TAR_EXIT != 0 )); then
        if (( EXIT_CODE == 0 )); then
            EXIT_CODE="${TAR_EXIT}"
        fi
    fi

    if (( EXIT_CODE == 0 )); then
        echo '[[[ SELF-CHECK PASS ]]]' | tee -a "${RUN_LOG}"
        if (( SELF_CHECK_ONLY == 1 )); then
            exit 0
        fi
        echo '[[[ SELF-CHECK DONE; CONTINUING... ]]]' | tee -a "${RUN_LOG}"
    else
        echo '[[[ SELF-CHECK FAIL ]]]' | tee -a "${RUN_LOG}"
        echo "SELF_DIR preserved: ${SELF_DIR}" | tee -a "${RUN_LOG}"
        exit "${EXIT_CODE}"
    fi
fi

if (( VERIFY_PRECHECK == 1 )); then
    echo '[[[ STARTING VERIFY SELF-CHECK... ]]]' | tee -a "${RUN_LOG}"
    echo "PWD: $(pwd)" | tee -a "${RUN_LOG}"
    echo "FIXER: ${FIXER}" | tee -a "${RUN_LOG}"
    "${FIXER}" --verify-self-check >> "${RUN_LOG}" 2>&1
    VERIFY_PRECHECK_EXIT=$?
    echo "VERIFY_PRECHECK_EXIT: ${VERIFY_PRECHECK_EXIT}" | tee -a "${RUN_LOG}"
    if (( VERIFY_PRECHECK_EXIT != 0 )); then
        echo '[[[ VERIFY SELF-CHECK FAIL ]]]' | tee -a "${RUN_LOG}"
        exit "${VERIFY_PRECHECK_EXIT}"
    fi
    echo '[[[ VERIFY SELF-CHECK PASS ]]]' | tee -a "${RUN_LOG}"
fi

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

echo "[[[ STARTING... ]]]" | tee -a "${RUN_LOG}"
echo "PWD: $(pwd)" | tee -a "${RUN_LOG}"
echo "FIXER: ${FIXER}" | tee -a "${RUN_LOG}"
echo "INPUT_PATTERNS: ${INPUT_PATTERNS[*]}" | tee -a "${RUN_LOG}"
echo "INPUT_COUNT: ${#INPUT_FILES[@]}" | tee -a "${RUN_LOG}"
echo "RUN_LINT: ${RUN_LINT}" | tee -a "${RUN_LOG}"
echo "PROMOTE: ${PROMOTE}" | tee -a "${RUN_LOG}"
echo "SELF_CHECK: ${SELF_CHECK}" | tee -a "${RUN_LOG}"
echo "OUTPUT_DIR: ${OUTPUT_DIR}" | tee -a "${RUN_LOG}"
echo "STAGE_DUMP_DIR: ${CHATGPT_MARKDOWN_FIX_STAGE_DIR:-}" | tee -a "${RUN_LOG}"
echo "STAGE_DUMP_MATCH: ${CHATGPT_MARKDOWN_FIX_STAGE_MATCH:-}" | tee -a "${RUN_LOG}"
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
    "${FIXER}" --clean "${RUN_FIXER_ARGS[@]}" "${INPUT_FILES[@]}" >> "${RUN_LOG}" 2>&1
    CLEAN_EXIT=$?
    if (( CLEAN_EXIT != 0 )); then
        echo "Clean step failed with exit code ${CLEAN_EXIT}" 1>&2
        echo "LOG: ${RUN_LOG}" 1>&2
        exit "${CLEAN_EXIT}"
    fi
fi

echo "[[[ FIXING... ]]]" | tee -a "${RUN_LOG}"
"${FIXER}" "${RUN_FIXER_ARGS[@]}" "${INPUT_FILES[@]}" >> "${RUN_LOG}" 2>&1
FIXER_EXIT=$?
LINT_EXIT=0
FIXED_FILES=()
FIXED_DEBUG_FILES=()

# Determine expected fixed outputs for linting and promotion
for in_f in "${INPUT_FILES[@]}"; do
    out_f="$(compute_fixed_output_path "${in_f}" "${OUTPUT_DIR}")"
    dbg_f="$(compute_debug_output_path "${out_f}")"

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

# Include self-check artifacts (if any)
if [[ -n "${SELF_DIR}" && -d "${SELF_DIR}" ]]; then
    for extra in         "${SELF_DIR}/chatgpt_good.md"         "${SELF_DIR}/chatgpt_bad.md"         "${SELF_DIR}/chatgpt_good__fixed.md"         "${SELF_DIR}/chatgpt_bad__fixed.md"         "${SELF_DIR}/chatgpt_good__fixed.debug"         "${SELF_DIR}/chatgpt_bad__fixed.debug"; do
        if [[ -f "${extra}" ]]; then
            TAR_FILES+=("$(realpath "${extra}")")
        fi
    done
fi

if [[ -n "${SELF_DIFF}" && -f "${SELF_DIFF}" ]]; then
    TAR_FILES+=("$(realpath "${SELF_DIFF}")")
fi

# Include deterministic stage snapshots (if configured and present)
if [[ -n "${CHATGPT_MARKDOWN_FIX_STAGE_DIR:-}" && -d "${CHATGPT_MARKDOWN_FIX_STAGE_DIR}" ]]; then
    TAR_FILES+=("$(realpath "${CHATGPT_MARKDOWN_FIX_STAGE_DIR}")")
fi

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
            out_f="$(compute_fixed_output_path "${in_f}" "${OUTPUT_DIR}")"

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

