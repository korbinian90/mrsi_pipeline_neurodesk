#!/usr/bin/env bash
#
# Smoke test for a built image. Checks that every component the pipeline needs
# is present and actually runs, rather than merely being installed.
#
# Usage:
#   docker run --rm -v "$PWD/container:/smoke:ro" mrsi-pipeline:local bash /smoke/smoke_test.sh
#
# Exits non-zero if any check fails, so it can gate a release.

fails=0

check() {
    local label="$1"; shift
    if output=$("$@" 2>&1); then
        printf '  ok    %-38s %s\n' "$label" "$(printf '%s' "$output" | head -1)"
    else
        printf '  FAIL  %-38s %s\n' "$label" "$(printf '%s' "$output" | head -2 | tr '\n' ' ')"
        fails=$((fails + 1))
    fi
}

echo "== pinned refs =="
for r in /opt/Part1 /opt/Part2 /opt/deepmrsi /opt/MRSI.jl; do
    printf '  %-16s %s\n' "$(basename "$r")" "$(git -C "$r" rev-parse --short HEAD 2>&1)"
done

echo
echo "== external tools =="
check "FSL bet"            bash -c 'command -v bet'
check "dcm2niix"           bash -c 'dcm2niix -h | head -1'
check "MINC rawtominc"     bash -c 'command -v rawtominc'
check "MINC mincresample"  bash -c 'command -v mincresample'
check "LCModel"            bash -c 'command -v lcmodel'
check "makehomogeneous"    bash -c 'test -x /opt/mritools/bin/makehomogeneous && echo present'
check "MATLAB Runtime"     bash -c 'test -d "${MATLAB_RUNTIME_ROOT}/runtime/glnxa64" && echo "${MATLAB_RUNTIME_ROOT}"'
check "MNI atlas"          bash -c 'test -d "${MNI_ATLAS_DIR}" && echo "${MNI_ATLAS_DIR}"'

echo
echo "== julia =="
# The bare case. Anything here that segfaults means the wrapper regressed.
check "julia starts"       julia --startup-file=no -e 'print(VERSION)'
check "MRSI.jl loads"      julia --startup-file=no -e 'using MRSI; print("MRSI ok")'
check "offline_pipeline"   julia --startup-file=no --project=/opt/deepmrsi/offline_pipeline -e 'using MRSI; print("project ok")'

# The case that actually bites: Part1 sources InstallProgramPaths.sh, which puts
# the MATLAB Runtime on LD_LIBRARY_PATH, and then calls run_julia_reco.jl. The
# unwrapped binary segfaults under exactly this environment.
check "julia under MCR LD_LIBRARY_PATH" \
    env LD_LIBRARY_PATH="${MATLAB_RUNTIME_ROOT}/sys/os/glnxa64:${MATLAB_RUNTIME_ROOT}/bin/glnxa64:${LD_LIBRARY_PATH}" \
    julia --startup-file=no -e 'using MRSI; print("MRSI ok under MCR")'

echo
echo "== python / deepmrsi =="
check "torch"              python -c 'import torch; print(torch.__version__, "cuda:", torch.version.cuda)'
check "deep_crt_mrsi"      python -c 'import deep_crt_mrsi; print("ok")'
check "mrs_utils"          python -c 'import mrs_utils; print("ok")'
check "walinet"            python -c 'import walinet; print("ok")'
check "forD"               python -c 'import forD; print("ok")'
check "forD_gpu_fit"       python -c 'import forD_gpu_fit; print("ok")'

echo
echo "== walinet models =="
if [ -d /opt/walinet_models ]; then
    for d in /opt/walinet_models/*/; do
        [ -d "$d" ] || continue
        printf '  %-24s %s\n' "$(basename "$d")" "$(du -sh "$d" 2>/dev/null | cut -f1)"
    done
    ls /opt/walinet_models/*.pt >/dev/null 2>&1 && printf '  %-24s %s\n' "(flat .pt files)" "$(ls /opt/walinet_models/*.pt | wc -l)"
else
    echo "  FAIL  /opt/walinet_models missing"
    fails=$((fails + 1))
fi

echo
echo "== pipeline entry points =="
check "Part1_ProcessMRSI.sh" bash -c 'test -x /opt/Part1/Part1_ProcessMRSI.sh && echo present'
check "run_julia_reco.jl"    bash -c 'test -f /opt/Part1/run_julia_reco.jl && echo present'
check "run_deepmrsi.py"      bash -c 'test -f /opt/Part1/run_deepmrsi.py && echo present'
check "Part1 compiled bins"  bash -c 'ls /opt/Part1/Matlab_Compiled/* >/dev/null 2>&1 && echo "$(ls /opt/Part1/Matlab_Compiled | wc -l) files"'
check "Part2 compiled bins"  bash -c 'ls /opt/Part2/Matlab_Compiled/* >/dev/null 2>&1 && echo "$(ls /opt/Part2/Matlab_Compiled | wc -l) files"'

echo
if [ "$fails" -eq 0 ]; then
    echo "ALL CHECKS PASSED"
else
    echo "$fails CHECK(S) FAILED"
fi
exit "$fails"
