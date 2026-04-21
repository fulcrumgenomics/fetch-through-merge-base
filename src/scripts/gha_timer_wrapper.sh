# shellcheck shell=bash
#
# Defines a `gha_timer` shell function that forwards to the
# fulcrumgenomics/gha-timer binary when it is present on PATH, and
# otherwise falls back to emitting GitHub Actions workflow commands
# (`::group::` / `::endgroup::`) so the log remains collapsible in the
# workflow UI.
#
# This file is intended to be `source`d from bash scripts and from
# inline `run:` blocks in action.yml.  It is NOT a standalone script.

gha_timer() {
    if command -v gha-timer >/dev/null 2>&1; then
        gha-timer "$@"
        return
    fi
    local subcommand="${1:-}"
    [ $# -gt 0 ] && shift
    local name=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --name)
                name="${2:-}"
                shift
                [ $# -gt 0 ] && shift
                ;;
            --outcome)
                shift
                [ $# -gt 0 ] && shift
                ;;
            *)
                shift
                ;;
        esac
    done
    case "$subcommand" in
        start)   echo "::group::${name}" ;;
        elapsed) echo "::endgroup::" ;;
        *)       : ;;
    esac
}
