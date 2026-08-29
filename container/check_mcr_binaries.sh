#!/usr/bin/env bash
#
# Check the compiled binaries actually start against the MATLAB Runtime.
#
# Compiling and running are separate failures. mcc can succeed and the binary
# still refuse to start, because the Runtime is a different version, because a
# library it needs is missing, or because a function was left out of the bundle
# and only surfaces at the first call. This starts each binary with no arguments
# and reads what comes back.
#
# A binary that starts prints its own usage or a MATLAB error about arguments.
# That is a pass: MATLAB got far enough to run the entry point. A loader error
# such as "error while loading shared libraries" or "Could not find version" is
# a fail, and so is a missing binary.
#
# Usage:
#   ./container/matlab_shell.sh bash /opt/tools/check_mcr_binaries.sh
#
# Environment:
#   BIN_DIR   compiled binaries   (default /opt/Part1/Matlab_Compiled)
#   MCR_DIR   MATLAB Runtime      (default the newest under /opt/MATLAB_Runtime_*)
set -uo pipefail

BIN_DIR="${BIN_DIR:-/opt/Part1/Matlab_Compiled}"
if [[ -z "${MCR_DIR:-}" ]]; then
    MCR_DIR=$(ls -d /opt/MATLAB_Runtime_*/* 2>/dev/null | sort | tail -1)
fi

if [[ -z "${MCR_DIR:-}" || ! -d "$MCR_DIR" ]]; then
    echo "ERROR: no MATLAB Runtime found; set MCR_DIR." >&2
    exit 1
fi

echo "Runtime : $MCR_DIR"
echo "Binaries: $BIN_DIR"
echo

export LD_LIBRARY_PATH="$MCR_DIR/runtime/glnxa64:$MCR_DIR/bin/glnxa64:$MCR_DIR/sys/os/glnxa64:$MCR_DIR/extern/bin/glnxa64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

Pass=0
Fail=()
for Binary in "$BIN_DIR"/*; do
    [[ -f "$Binary" && -x "$Binary" ]] || continue
    Name=$(basename "$Binary")
    case "$Name" in *.sh|*.txt|*.log|*.json) continue;; esac

    Output=$("$Binary" 2>&1 </dev/null | head -20)
    if grep -qiE "error while loading shared libraries|cannot open shared object|Could not find version|MATLAB Runtime.*not.*installed|No such file or directory" <<<"$Output"; then
        echo "FAIL  $Name"
        sed 's/^/        /' <<<"$Output" | head -4
        Fail+=("$Name")
    else
        echo "OK    $Name (started against the Runtime)"
        Pass=$((Pass + 1))
    fi
done

echo
if (( ${#Fail[@]} )); then
    echo "$Pass started, ${#Fail[@]} failed: ${Fail[*]}" >&2
    exit 1
fi
if (( Pass == 0 )); then
    echo "ERROR: no binaries found in $BIN_DIR." >&2
    exit 1
fi
echo "$Pass binaries start against the Runtime."
