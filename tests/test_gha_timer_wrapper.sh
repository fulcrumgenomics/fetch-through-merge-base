#!/usr/bin/env bash
#
# Unit test for src/scripts/gha_timer_wrapper.sh.
#
# Covers both branches of the wrapper:
#   1. gha-timer present on PATH: arguments are forwarded verbatim and
#      no ::group::/::endgroup:: marker is emitted.
#   2. gha-timer absent from PATH: the fallback emits the expected
#      ::group:: / ::endgroup:: workflow commands and is silent on
#      `stop` (no analogue in workflow commands).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRAPPER="${REPO_ROOT}/src/scripts/gha_timer_wrapper.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# --- case 1: real binary shimmed onto PATH → pass-through, no fallback output ---
SHIM_DIR="${TMP}/shim"
mkdir -p "${SHIM_DIR}"
cat > "${SHIM_DIR}/gha-timer" <<'EOF'
#!/usr/bin/env bash
# Record argv, one arg per line, for the test to inspect.
printf '%s\n' "$@" > "${GHA_TIMER_SHIM_LOG}"
EOF
chmod +x "${SHIM_DIR}/gha-timer"

export GHA_TIMER_SHIM_LOG="${TMP}/shim.log"
PATH="${SHIM_DIR}:${PATH}"
# shellcheck source=../src/scripts/gha_timer_wrapper.sh
. "${WRAPPER}"

out="$(gha_timer start --name "Hello, 🦝")"
if [ -n "${out}" ]; then
    echo "FAIL (case 1): wrapper emitted output when gha-timer is on PATH"
    echo "  got: ${out}"
    exit 1
fi
expected_argv=$'start\n--name\nHello, 🦝'
if [ "$(cat "${GHA_TIMER_SHIM_LOG}")" != "${expected_argv}" ]; then
    echo "FAIL (case 1): shim did not receive expected argv"
    echo "--- expected ---"; printf '%s\n' "${expected_argv}"
    echo "--- actual ---"; cat "${GHA_TIMER_SHIM_LOG}"
    echo "----------------"
    exit 1
fi
echo "PASS (case 1): wrapper forwards argv verbatim when gha-timer is on PATH"

# --- case 2: gha-timer absent → fallback emits ::group::/::endgroup:: ---
# Run the case in a fresh subshell with a PATH that does not contain
# the shim (and does not contain any system-installed gha-timer).  The
# parent shell's `gha_timer` function is not `export -f`'d, so it does
# not cross into the child bash process; re-sourcing the wrapper inside
# the child installs a fresh function that picks the fallback branch
# because gha-timer is absent from the child's PATH.
fallback_out="$(
    PATH="/usr/bin:/bin" bash -c '
        set -euo pipefail
        . "'"${WRAPPER}"'"
        gha_timer start --name "Step A"
        gha_timer elapsed --outcome success --name "Step A"
        gha_timer stop
    '
)"
expected_fallback=$'::group::Step A\n::endgroup::'
if [ "${fallback_out}" != "${expected_fallback}" ]; then
    echo "FAIL (case 2): fallback output mismatch"
    echo "--- expected ---"; printf '%s\n' "${expected_fallback}"
    echo "--- actual ---"; printf '%s\n' "${fallback_out}"
    echo "----------------"
    exit 1
fi
echo "PASS (case 2): fallback emits ::group::/::endgroup:: and drops 'stop'"

echo "PASS: test_gha_timer_wrapper.sh"
