#!/usr/bin/env bash
#
# The 7T no-water-reference setting matrix, against a shipping image.
#
# Usage: matrix_7t.sh <dat> <out_root> [name ...]
# With no names, every configuration runs, in the order listed.
set -uo pipefail

Here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
Dat=$1; OutRoot=$2; shift 2
# Tom masks from an anatomical, which is also the only supported way: the -m bet
# branch runs the outskin BET only when a T1 is given, and consumes its output
# unconditionally, so -m bet on its own breaks the MINC chain.
T1='/out/synthetic_t1.mnc'

# name|expected exit|args
Configs=(
  "julia-lcm|0|-S auto"
  "julia-l2-lcm|0|-S auto|-L|L2,1e-3"
  "julia-walinet-lcm|0|-S auto|-L|WALINET,7T"
  # -Q takes the fitter alone; WALINET is a -L method like L1 and L2.
  "julia-gpufit|0|-S auto|-Q|gpufit"
  "julia-dlfit|0|-S auto|-Q|dlfit"
  "julia-walinet-gpufit|0|-S auto|-L|WALINET,7T|-Q|gpufit"
  "julia-walinet-b0-gpufit|0|-S auto|-A|Patref|-L|WALINET,7T|-Q|gpufit"
  # -0 with no WALINET: nothing corrects before deepmrsi, so deepmrsi does it.
  # The parity partner of the two above; all three must measure the same map.
  "julia-b0-gpufit|0|-S auto|-A|Patref|-Q|gpufit"
  # -A Patref on the MATLAB reconstruction. Same estimator, other implementation:
  # compare_b0_maps.py checks the two against each other and against calculate_B0.
  "matlab-patref-gpufit|0||-A|Patref|-Q|gpufit"
  # Alignment and Overdiscrete live in the MATLAB reconstruction, so -S refuses
  # them rather than building a map it would discard.
  "refuse-align-no-julia|1|-S auto|-A|Alignment"
  # A typo in the method must not fall through to the peak search.
  "refuse-align-unknown|1|-S auto|-A|Patrf"
  "julia-walinet-dlfit|0|-S auto|-L|WALINET,7T|-Q|dlfit"
  "julia-l2-gpufit|0|-S auto|-L|L2,1e-3|-Q|gpufit"
  "julia-l2-dlfit|0|-S auto|-L|L2,1e-3|-Q|dlfit"
  "julia-l1-lcm|0|-S auto|-L|L1,10"
  "matlab-lcm|0|"
  "matlab-l2-lcm|0||-L|L2,1e-3"
  "refuse-walinet-no-julia|1||-L|WALINET,7T"
  "refuse-walinet-3t|1|-S auto|-L|WALINET,3T"
  # -t AND -m together: the only combination that runs the outskin BET and so
  # exercises ExtractBrain_mask and flip_mask on a mask that is not all ones.
  "julia-lcm-betmask|0|-S auto|-m|bet,-f 0.65 -g 0.1"
)

Wanted=("$@")
want() {
    (( ${#Wanted[@]} == 0 )) && return 0
    local w; for w in "${Wanted[@]}"; do [[ "$w" == "$1" ]] && return 0; done
    return 1
}

for Entry in "${Configs[@]}"; do
    IFS='|' read -ra Fields <<< "$Entry"
    Name=${Fields[0]}; Expected=${Fields[1]}
    Args=()
    for (( i=2; i<${#Fields[@]}; i++ )); do
        [[ -n "${Fields[$i]}" ]] || continue
        # Only "-S auto" is a field carrying two separate arguments. Everything
        # else stays one argument however many spaces it has: -m takes its bet
        # options as a single word, and splitting them is how the 2026-08-30
        # matrix ended up passing -m "bet,-f" with the rest as stray arguments.
        if [[ "${Fields[$i]}" == "-S "* ]]; then
            read -ra Parts <<< "${Fields[$i]}"
            Args+=("${Parts[@]}")
        else
            Args+=("${Fields[$i]}")
        fi
    done
    Args+=(-t "$T1")

    want "$Name" || continue

    "$Here/run_matrix.sh" "$Name" "$Dat" "$OutRoot" -- "${Args[@]}"
    Got=$(awk -F'\t' -v n="$Name" '$1==n {sub("exit=","",$2); e=$2} END {print e}' "$OutRoot/matrix_results.tsv")
    if [[ "$Got" == "$Expected" ]]; then
        echo "  EXPECTED exit $Expected"
    else
        echo "  UNEXPECTED: exit $Got, wanted $Expected"
    fi
    echo
done
