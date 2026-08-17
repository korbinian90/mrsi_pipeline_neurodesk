#!/usr/bin/env julia
# Julia MRSI Reconstruction entry script
# Called by run_matlab.sh when the -S (Julia) flag is used.
# Usage: julia run_julia_reco.jl <tmp_dir> <cur_avg> <mmap>
#
# Arguments:
#   tmp_dir  : path to the temporary directory containing InitialParameters.m
#   cur_avg  : 1-based index of the current average (1 = first/only, or water reference when WaterReference_flag=1)
#   mmap     : "true", "false", or "auto" (memory-mapping mode for MRSI.jl)
#
# Behaviour:
#   - Reads InitialParameters.m from tmp_dir to retrieve flags and paths.
#   - Calls MRSI.reconstruct() with parameters mapped from the InitialParameters flags.
#   - For multi-average acquisitions, accumulates into <out_path>/julia_csi.raw
#     (same logic as MRSI_Reconstruction.m: load → add → save, divide on last avg).
#   - The water reference pass (CurAvg=1, WaterReference.mat absent) is detected and
#     written to <out_path>/julia_csi_watref.raw instead of the metabolite file.
#   - After the last metabolite average the script writes <tmp_dir>/julia_recoinfo.m
#     with CSI dimensions needed by julia_write_lcm_files (MATLAB side).
#
# Output written to out_path:
#   julia_csi.raw           – accumulated complex float32, interleaved Re/Im, [Nx,Ny,Nz,Nt]
#   julia_csi_watref.raw    – same layout, water reference only (if WaterReference_flag=1)
#   (tmp_dir)/julia_recoinfo.m – MATLAB-readable CSI dimension / metadata file

import Pkg
# Ensure MRSI.jl is available (path set in InstallProgramPaths.sh via JULIA_LOAD_PATH or Pkg.activate)
if haskey(ENV, "JULIA_MRSI_PKG")
    Pkg.activate(ENV["JULIA_MRSI_PKG"]; io=devnull)
end
using MRSI

# ─── helpers ──────────────────────────────────────────────────────────────────

"""Parse a MATLAB-syntax InitialParameters.m text file into a Dict."""
function parse_initial_parameters(path::String)
    params = Dict{String,Any}()
    cell_arrays = Dict{String,Vector{String}}()

    for raw_line in eachline(path)
        line = strip(raw_line)
        isempty(line) && continue
        startswith(line, '%') && continue

        # Cell array entry:  name{N} = 'value';
        m = match(r"^(\w+)\{(\d+)\}\s*=\s*'([^']*)'\s*;", line)
        if m !== nothing
            k, n, v = String(m[1]), parse(Int, m[2]), String(m[3])
            arr = get!(cell_arrays, k, String[])
            while length(arr) < n; push!(arr, ""); end
            arr[n] = v
            continue
        end

        # Simple assignment:  name = value;
        m = match(r"^(\w+)\s*=\s*(.+?)\s*;?\s*$", line)
        m === nothing && continue
        key = String(m[1])
        val = strip(String(m[2]))

        # Strip trailing semicolon if present
        val = rstrip(val, ';')

        # Quoted string
        if startswith(val, "'") && endswith(val, "'")
            params[key] = val[2:end-1]
        # Integer 0 or 1
        elseif val ∈ ("0", "1")
            params[key] = parse(Int, val)
        # Other integer
        elseif match(r"^\d+$", val) !== nothing
            params[key] = parse(Int, val)
        # Float
        elseif match(r"^-?\d+(\.\d+)?([eE][+-]?\d+)?$", val) !== nothing
            params[key] = parse(Float64, val)
        else
            # Store as raw string (e.g. bracketed arrays, expressions)
            params[key] = val
        end
    end

    # Merge cell arrays into params
    for (k, v) in cell_arrays
        params[k] = v
    end

    return params
end

"""Parse a MATLAB gradient delay string like "[12.56, 12.54, 10.08]" into a Vector{Float64}.
Complex format "[12.42+10.27im, ...]" is also handled."""
function parse_gradient_delays(s::String)
    s = strip(s, ['[', ']', ' '])
    parts = split(s, ',')
    result = ComplexF64[]
    for p in parts
        p = strip(p)
        # Try complex: "a+bim" or "a-bim"
        m = match(r"^(-?[\d.]+(?:[eE][+-]?\d+)?)\s*([+-]\s*[\d.]+(?:[eE][+-]?\d+)?)im$", p)
        if m !== nothing
            re = parse(Float64, replace(String(m[1]), " " => ""))
            im_part = parse(Float64, replace(String(m[2]), " " => ""))
            push!(result, complex(re, im_part))
        else
            # Real only → store as real complex (imaginary = 0)
            push!(result, complex(parse(Float64, p), 0.0))
        end
    end
    return result
end

"""Write complex float32 data to a binary file (interleaved Re/Im)."""
function write_complex_raw(path::String, data::AbstractArray{<:Complex})
    open(path, "w") do fid
        for x in data
            write(fid, Float32(real(x)))
            write(fid, Float32(imag(x)))
        end
    end
end

"""Read complex float32 binary file back into an array of ComplexF32."""
function read_complex_raw(path::String, sz::NTuple)
    n = prod(sz)
    buf = Array{Float32}(undef, 2*n)
    read!(path, buf)
    data = Array{ComplexF32}(undef, sz...)
    for i in 1:n
        data[i] = ComplexF32(buf[2i-1], buf[2i])
    end
    return data
end

# ─── main ─────────────────────────────────────────────────────────────────────

length(ARGS) < 2 && error("Usage: julia run_julia_reco.jl <tmp_dir> <cur_avg> [mmap]")

tmp_dir  = ARGS[1]
cur_avg  = parse(Int, ARGS[2])
mmap_arg = length(ARGS) >= 3 ? ARGS[3] : "auto"

par_file = joinpath(tmp_dir, "InitialParameters.m")
isfile(par_file) || error("InitialParameters.m not found in $tmp_dir")

p = parse_initial_parameters(par_file)

out_path    = get(p, "out_path", "")
csi_paths   = get(p, "csi_path", String[])
n_files     = length(csi_paths)

isempty(out_path) && error("out_path not found in InitialParameters.m")
isempty(csi_paths) && error("csi_path not found in InitialParameters.m")

# ── Determine if this call is the water reference pass ─────────────────────
# Water reference: WaterReference_flag=1 and WaterReference.mat does not yet exist
is_water_ref = false
if get(p, "WaterReference_flag", 0) == 1
    watref_mat = joinpath(out_path, "WaterReference.mat")
    if !isfile(watref_mat)
        is_water_ref = true
        println("Julia: Detected water reference pass.")
    end
end

# ── Select input file ────────────────────────────────────────────────────────
if is_water_ref
    # Water reference: the path is stored in csi_path{1} but parameters_water.mat
    # has overridden it already. We use csi_path{1} from InitialParameters as fallback.
    # If WaterReference_MethodAndFile is set use its path component.
    watref_setting = get(p, "WaterReference_MethodAndFile", "")
    if !isempty(watref_setting)
        # Format: "Method,/path/to/file" or just "Method" (same file as metabolite)
        parts = split(watref_setting, ',')
        dat_file = length(parts) >= 2 ? strip(parts[2]) : csi_paths[1]
        isempty(dat_file) && (dat_file = csi_paths[1])
    else
        dat_file = csi_paths[1]
    end
else
    idx = clamp(cur_avg, 1, n_files)
    dat_file = csi_paths[idx]
end

isfile(dat_file) || error("CSI data file not found: $dat_file")
println("Julia: Reconstructing file: $dat_file  (avg $cur_avg, is_water_ref=$is_water_ref)")

# ── Map flags to MRSI.reconstruct() keyword arguments ───────────────────────
hamming_flag     = get(p, "hamming_flag", 0) == 1
noisedecor_flag  = get(p, "noisedecorrelation_flag", 0) == 1
lipid_flag       = get(p, "LipidDecon_flag", 0) == 1
grad_delay_flag  = get(p, "GradientDelay_flag", 0) == 1
zero_fill_flag   = get(p, "ZeroFillMetMaps_flag", 0) == 1  # zerofilling the maps

# Lipid deconvolution method
lipid_decon = nothing
if lipid_flag
    lcm_str = get(p, "LipidDecon_MethodAndNoOfLoops", "L2,10")
    method = uppercase(split(lcm_str, ',')[1])
    lipid_decon = method == "L1" ? :L1 : :L2
end

# Gradient delay
gradient_delay_us = [12.42+10.27im, 12.38+10.75im, 10.14+8.99im]  # MRSI.jl defaults
if grad_delay_flag
    gd_str = string(get(p, "GradientDelay", ""))
    if !isempty(gd_str) && gd_str != "0"
        try
            gradient_delay_us = parse_gradient_delays(gd_str)
        catch e
            @warn "Could not parse GradientDelay '$gd_str', using MRSI.jl defaults: $e"
        end
    end
end

# Memory mapping
mmap_val = mmap_arg == "true"  ? true  :
           mmap_arg == "false" ? false :
           :auto

println("Julia: Calling MRSI.reconstruct() ...")
println("  hamming=$hamming_flag, noise_decorrelation=$noisedecor_flag, lipid_decon=$lipid_decon")
println("  gradient_delay_us=$gradient_delay_us, mmap=$mmap_val, zero_fill=$zero_fill_flag")

# ── Reconstruct ───────────────────────────────────────────────────────────────
# NOTE: MRSI.reconstruct() is expected to return the complex CSI array with
# dimensions [Nx, Ny, Nz, Nt] (spatial × spectral), or a NamedTuple containing
# it. Adjust the extraction below if the actual return type differs.

result = MRSI.reconstruct(
    dat_file;
    datatype              = ComplexF32,
    mmap                  = mmap_val,
    do_noise_decorrelation = noisedecor_flag,
    do_hamming_filter     = hamming_flag,
    do_hamming_filter_z   = hamming_flag,
    lipid_decon           = lipid_decon,
    gradient_delay_us     = gradient_delay_us,
    zero_fill             = zero_fill_flag,
)

# Extract the CSI array from the result
# MRSI.reconstruct() returns the CSI data array directly (ComplexF32).
# If it returns a NamedTuple/struct, adapt accordingly.
if result isa AbstractArray
    csi_data = Array{ComplexF32}(result)
elseif hasproperty(result, :data)
    csi_data = Array{ComplexF32}(result.data)
elseif hasproperty(result, :csi)
    csi_data = Array{ComplexF32}(result.csi)
else
    error("Unexpected return type from MRSI.reconstruct(): $(typeof(result)). " *
          "Please update run_julia_reco.jl to extract the CSI array.")
end

sz = size(csi_data)   # (Nx, Ny, Nz, Nt) or (Nx, Ny, Nt) for 2D
println("Julia: Reconstruction done. CSI size: $sz")

# ── Output file paths ─────────────────────────────────────────────────────────
if is_water_ref
    out_raw = joinpath(out_path, "julia_csi_watref.raw")
else
    out_raw = joinpath(out_path, "julia_csi.raw")
end

# ── Average accumulation (metabolite averages only) ───────────────────────────
if !is_water_ref && n_files > 1
    if cur_avg > 1 && isfile(out_raw)
        println("Julia: Loading existing accumulated data and adding avg $cur_avg ...")
        prev = read_complex_raw(out_raw, sz)
        csi_data .+= prev
    end
    # Divide by number of averages on the last one
    if cur_avg == n_files
        println("Julia: Dividing by $n_files averages.")
        csi_data ./= Float32(n_files)
    end
end

# ── Write output ──────────────────────────────────────────────────────────────
println("Julia: Writing $out_raw ...")
write_complex_raw(out_raw, csi_data)

# ── Write recoinfo for MATLAB (only after last metabolite average) ─────────────
if !is_water_ref && (n_files <= 1 || cur_avg == n_files)
    Nx = sz[1]
    Ny = sz[2]
    Nz = length(sz) >= 4 ? sz[3] : 1
    Nt = sz[end]

    recoinfo_path = joinpath(tmp_dir, "julia_recoinfo.m")
    println("Julia: Writing $recoinfo_path ...")
    open(recoinfo_path, "w") do f
        println(f, "% Auto-generated by run_julia_reco.jl — do not edit")
        println(f, "julia_csi_Nx = $Nx;")
        println(f, "julia_csi_Ny = $Ny;")
        println(f, "julia_csi_Nz = $Nz;")
        println(f, "julia_csi_Nt = $Nt;")
        println(f, "julia_csi_raw = '$(joinpath(out_path, "julia_csi.raw"))';")
        println(f, "julia_csi_watref_raw = '$(joinpath(out_path, "julia_csi_watref.raw"))';")
    end
end

println("Julia: Done.")
