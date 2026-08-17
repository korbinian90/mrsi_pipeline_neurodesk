#!/bin/bash

# Argument $1: name of matlab script
run_matlab() {
    if [[ $compiled_matlab_flag -eq 1 ]]; then
        # run the compiled matlab function
        echo -e "\nRun this command: $MatlabCompiledFunctions/$1 $abs_tmp_dir"
        "$MatlabCompiledFunctions/$1" "$abs_tmp_dir"
    else
        # run the matlab script $1
        echo -e "\nRun this command: $matlabp -nodisplay -batch \"addpath(genpath('$MatlabFunctionsFolder')); $1('$abs_tmp_dir')\""
        $matlabp -nodisplay -batch "addpath(genpath('$MatlabFunctionsFolder')); $1('$abs_tmp_dir')"
    fi
}

# Check whether the current run_mrsi_reconstruction call is the water reference pass.
# Returns 0 (true) if it is, 1 (false) otherwise.
_is_water_ref_pass() {
    if [[ $WaterReference_flag -eq 1 ]] && [[ ! -f "${out_path}/WaterReference.mat" ]]; then
        return 0
    fi
    return 1
}

# Argument $1: CurAv argument for MRSI_Reconstruction.m
run_mrsi_reconstruction() {
    local cur_avg="$1"

    if [[ $julia_reconstruction -eq 1 ]]; then
        # ── Check for flags that Julia does not support ──────────────────────
        local incompatible_flags=()
        [[ $TwoDCaipParallelImaging_flag  -eq 1 ]] && incompatible_flags+=("TwoDCaipParallelImaging (-r)")
        [[ $SliceParallelImaging_flag     -eq 1 ]] && incompatible_flags+=("SliceParallelImaging (-R)")
        [[ $NonCartTraj_flag              -eq 1 ]] && incompatible_flags+=("NonCartesianTrajectory (-s)")
        [[ $TimeInterpolation_flag        -eq 1 ]] && incompatible_flags+=("TimeInterpolation (-T)")
        [[ $FirstOrderPhaseCorr_flag      -eq 1 ]] && incompatible_flags+=("FirstOrderPhaseCorr (-F)")
        [[ $FirstOrderPhaseModulation_flag -eq 1 ]] && incompatible_flags+=("FirstOrderPhaseModulation (-k)")
        [[ $NuisRem_flag                  -eq 1 ]] && incompatible_flags+=("NuisanceRemoval (-n)")

        if [[ ${#incompatible_flags[@]} -gt 0 ]]; then
            echo "WARNING: Julia reconstruction requested but the following flags are not supported by Julia:"
            for f in "${incompatible_flags[@]}"; do echo "  - $f"; done
            echo "Falling back to MATLAB for this reconstruction."

        elif _is_water_ref_pass; then
            # Water reference: Julia output would need to produce WaterReference.mat
            # which requires MATLAB's MAT-file library. Use MATLAB for this pass.
            echo "Note: Water reference reconstruction handled by MATLAB (MAT-file output required)."

        else
            # ── Julia reconstruction path ─────────────────────────────────────
            local script_dir
            script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
            echo -e "\nJulia reconstruction: avg=$cur_avg, threads=$julia_n_threads, mmap=$julia_mmap"
            echo "Run: JULIA_NUM_THREADS=$julia_n_threads julia $script_dir/run_julia_reco.jl $abs_tmp_dir $cur_avg $julia_mmap"

            JULIA_NUM_THREADS="$julia_n_threads" \
                julia "$script_dir/run_julia_reco.jl" "$abs_tmp_dir" "$cur_avg" "$julia_mmap"

            if [[ $? -eq 0 ]]; then
                # Only write LCModel files after the last metabolite average
                local is_last_avg=0
                if [[ -z "$NumberOfCSIFiles" ]] || [[ $cur_avg -ge $NumberOfCSIFiles ]]; then
                    is_last_avg=1
                fi
                if [[ $is_last_avg -eq 1 ]]; then
                    echo -e "\nJulia reconstruction finished. Writing LCModel files via julia_write_lcm_files ..."
                    echo "Run: $MatlabCompiledFunctions/julia_write_lcm_files $abs_tmp_dir"
                    "$MatlabCompiledFunctions/julia_write_lcm_files" "$abs_tmp_dir"
                fi
                return $?
            else
                echo "Julia reconstruction failed (exit code $?). Falling back to MATLAB."
            fi
        fi
    fi

    # ── MATLAB reconstruction (default / fallback) ────────────────────────────
    if [[ $compiled_matlab_flag -eq 1 ]]; then
        echo -e "\nRun this command: $MatlabCompiledFunctions/MRSI_Reconstruction $abs_tmp_dir $cur_avg"
        "$MatlabCompiledFunctions/MRSI_Reconstruction" "$abs_tmp_dir" "$cur_avg"
    else
        echo -e "\nRun this command: $matlabp -nodisplay -batch \"addpath(genpath('$MatlabFunctionsFolder')); MRSI_Reconstruction('$abs_tmp_dir', $cur_avg)\""
        $matlabp -nodisplay -batch "addpath(genpath('$MatlabFunctionsFolder')); MRSI_Reconstruction('$abs_tmp_dir', $cur_avg)"
    fi
}
