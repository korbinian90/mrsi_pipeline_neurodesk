#!/bin/bash
#
# What produced this image, and what it will do by default.
#
# The four source refs are baked in at build time as /opt/mrsi_build_refs; the
# rest is read from the image so it cannot drift from what actually runs.
set -uo pipefail

Config=/opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install

json_field() {
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get(sys.argv[2], "?"))' \
        "$1" "$2" 2>/dev/null || echo "?"
}

cat /opt/mrsi_build_refs 2>/dev/null || echo "no /opt/mrsi_build_refs; this image predates it"
echo
printf 'MATLAB Runtime %s\n' "$(basename "$(ls -d /opt/MATLAB_Runtime_*/* 2>/dev/null | sort | tail -1)")"
printf 'Julia          %s\n' "$(julia --startup-file=no -e 'print(VERSION)' 2>/dev/null)"
printf 'torch          %s\n' "$(python3 -c 'import torch; print(torch.__version__)' 2>/dev/null)"
printf 'CUDA visible   %s\n' "$(python3 -c 'import torch; print(torch.cuda.is_available())' 2>/dev/null)"
echo
printf 'WALINET models %s\n' "$(ls /opt/walinet_models 2>/dev/null | tr '\n' ' ')"
printf 'walinet model  %s\n' "$(json_field "$Config/walinet/package_config.json" model_relative_path)"
printf 'fitting        %s\n' "$(json_field "$Config/deep_crt_mrsi/package_config.json" fitting)"
printf 'apply_walinet  %s\n' "$(json_field "$Config/deep_crt_mrsi/package_config.json" apply_walinet)"
echo

# A compiled binary carries no version of its own, and mcc seals the source into
# an encrypted archive, so the hash is the only thing that ties one to the commit
# the refs above name.
echo 'compiled MATLAB binaries'
for Dir in /opt/Part1/Matlab_Compiled /opt/Part2/Matlab_Compiled; do
    Part=$(basename "$Dir" | sed 's/_Compiled//')
    for Bin in "$Dir"/*; do
        [ -f "$Bin" ] && [ -x "$Bin" ] || continue
        case "$Bin" in *.sh|*.txt|*.json|*.log) continue ;; esac
        echo "  $Part $(basename "$Bin") $(sha256sum "$Bin" | cut -c1-16)"
    done
done
