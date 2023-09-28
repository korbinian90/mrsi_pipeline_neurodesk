using MAT, MRSI, Comonicon

function create_args(old_datfile, lipid_decon_setting, tmp_dir, mmap)
    d = Dict{Symbol, Any}()
    d[:old_headers] = (old_datfile == 1)
    if mmap == "false"
        d[:mmap] = false
    elseif mmap == "true"
        d[:mmap] = true
    else
        d[:mmap] = mmap
    end
    add_lipid_decon_args!(d, lipid_decon_setting, tmp_dir)

    return d
end

function add_lipid_decon_args!(d, lipid_decon_setting, tmp_dir)
    if lipid_decon_setting == "false"
        return
    end
    type, arg = split(lipid_decon_setting, ',')

    if type in ["L1", "L2"]
        d[:lipid_decon] = Symbol(type)
        if type == "L1"
            d[:L1_n_loops] = parse(Int, arg)
        else
            d[:L2_beta] = parse(Float64, arg)
        end
    
        fn_brain_mask = joinpath(tmp_dir,"/mask_brain.raw")
        if isfile(fn_brain_mask)
            d[:brain_mask] = fn_brain_mask
        end
        fn_lipid_mask = joinpath(tmp_dir,"/mask_lipid.raw")
        if isfile(fn_lipid_mask)
            d[:lipid_mask] = fn_lipid_mask
        end
    end
end

"""
Perform MRSI CRT reconstruction in Julia.

# Args

- `old_datfile`: 1 for old datfiles or 0 for datfiles after sequence merging
- `dat_file`: Input SIEMENS dat file
- `tmp_dir`: Directory for mask_brain.raw and mask_lipid.raw
- `out_dir`: Output folder for the CombinedCSI.mat file
- `lipid_decon_setting`: For example "L1,5"
- `mmap`: "true", "false" or a path
"""
@main function julia_reco(old_datfile, dat_file, tmp_dir, out_dir, lipid_decon_setting, mmap)
    args = create_args(old_datfile, lipid_decon_setting, tmp_dir, mmap)

    reconstructed = reconstruct(dat_file; args...)
    
    info = extract_twix(dat_file, :ONLINE)
    matwrite(joinpath(out_dir, "CombinedCSI.mat"), Dict(
        "csi" => reconstructed,
        "larmor_frequency" => info[:larmor_frequency],
        "dwelltime" => info[:dwelltime]))
    return
end

