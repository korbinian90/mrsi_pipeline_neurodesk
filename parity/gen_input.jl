# Generate deterministic inputs shared by the MATLAB and Julia sides of the
# parity harness. Written as flat Float64 (all real parts, then all imaginary
# parts) so MATLAB's fread and Julia's read agree byte for byte. Both languages
# are column-major and 1-based, so no index juggling is needed.
using Random

const IO_DIR = joinpath(@__DIR__, "io")

function write_complex(name, a)
    open(joinpath(IO_DIR, name), "w") do f
        write(f, Float64.(real(a)))
        write(f, Float64.(imag(a)))
    end
    open(joinpath(IO_DIR, name * ".size"), "w") do f
        println(f, join(size(a), " "))
    end
end

mkpath(IO_DIR)
Random.seed!(20260818)

# 5-D CSI-shaped array (nx, ny, nz, n_fid, n_cha) with an odd and an even nz.
for (tag, dims) in (("csi_odd", (6, 5, 21, 4, 3)), ("csi_even", (6, 5, 8, 4, 3)))
    write_complex("$(tag).bin", randn(ComplexF64, dims))
end

# Reference scan for the coil-combination test: same spatial dims, one FID point
# used as the weight source, deliberately including a zero-signal voxel so the
# 1/0 guard on both sides is exercised.
ref = randn(ComplexF64, (6, 5, 21, 4, 3))
ref[1, 1, 1, :, :] .= 0
write_complex("ref.bin", ref)

# Reference scan with only 3 FID points. MRSI_Reconstruction.m:568-572 falls back
# to point 1 whenever size(image.Data,4) <= 3, while MRSI.jl clamps the requested
# point to the last available one. This input makes that difference observable.
write_complex("ref3.bin", randn(ComplexF64, (6, 5, 21, 3, 3)))

println("wrote inputs to ", IO_DIR)
