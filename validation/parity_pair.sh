#!/usr/bin/env bash
#
# Reconstruct one dataset both ways and compare the field maps they measure.
#
#   parity_pair.sh <dat> <out_root>
#
# The MATLAB route and the Julia route in MATLAB parity mode, each with
# -A Patref so both write AlignFreq/B0map_Hz.raw, then compare_b0_maps.py.
set -uo pipefail
Here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Dat=$1; OutRoot=$2
export IMAGE="${IMAGE:-mrsi-pipeline:7t-rc9}"
mkdir -p "$OutRoot"

# No -t and no -m: masking needs an anatomical in the CSI geometry, which a
# dataset from another session does not have, and the field map does not use it.
"$Here/run_matrix.sh" matlab-patref "$Dat" "$OutRoot" -- -A Patref -Q gpufit
"$Here/run_matrix.sh" julia-patref "$Dat" "$OutRoot" -- -S "auto,matlab" -A Patref -Q gpufit

MSYS_NO_PATHCONV=1 docker run --rm -v "$OutRoot:/out" \
    -v "$Here/compare_b0_maps.py:/out/compare_b0_maps.py:ro" \
    --entrypoint /bin/bash "$IMAGE" -c \
    '/opt/venv/bin/python3 /out/compare_b0_maps.py /out/matlab-patref /out/julia-patref'
