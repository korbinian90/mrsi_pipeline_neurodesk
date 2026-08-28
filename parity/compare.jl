# Julia half of the parity harness plus the comparison.
#
# Each test runs the MRSI.jl function against the output MATLAB produced from
# the identical input, and reports the worst absolute and relative difference.
# "Relative" is normalised by the largest magnitude in the MATLAB result, so it
# does not blow up on near-zero voxels.

using MRSI
using Printf

const IO_DIR = joinpath(@__DIR__, "io")

function read_complex(name)
    dims = parse.(Int, split(strip(read(joinpath(IO_DIR, name * ".size"), String))))
    raw = reinterpret(Float64, read(joinpath(IO_DIR, name)))
    n = length(raw) ÷ 2
    return reshape(complex.(raw[1:n], raw[n+1:end]), dims...)
end

results = Tuple{String,Float64,Float64,Bool}[]

function check(label, julia_result, matlab_name; tol=1e-12)
    m = read_complex(matlab_name)
    j = ComplexF64.(julia_result)
    if size(j) != size(m)
        @printf("%-34s SHAPE MISMATCH julia=%s matlab=%s\n", label, size(j), size(m))
        push!(results, (label, NaN, NaN, false))
        return
    end
    absdiff = maximum(abs.(j .- m))
    scale = maximum(abs.(m))
    reldiff = scale == 0 ? absdiff : absdiff / scale
    ok = reldiff <= tol
    push!(results, (label, absdiff, reldiff, ok))
    @printf("%-34s max|d|=%-11.3e rel=%-11.3e %s\n", label, absdiff, reldiff, ok ? "PASS" : "FAIL")
end

csi_odd = read_complex("csi_odd.bin")
csi_even = read_complex("csi_even.bin")
ref = read_complex("ref.bin")

println("=== T1  Hamming window values (MATLAB hamming(n) vs MRSI.hamming_filter) ===")
for n in (8, 21, 31)
    jw = MRSI.hamming_filter.(range(-0.5, 0.5, n))
    check("window n=$n", reshape(ComplexF64.(jw), n, 1), "m_window_$(n).bin")
end

println("\n=== T2  z-Hamming filter, image domain (MRSI_Reconstruction.m:674) ===")
check("hamming_filter_z! odd nz=21", MRSI.hamming_filter_z!(copy(csi_odd)), "m_hammz_odd.bin")
check("hamming_filter_z! even nz=8", MRSI.hamming_filter_z!(copy(csi_even)), "m_hammz_even.bin")

println("\n=== T3  slice-dim FFT convention ===")
check("fft_slice_dim", MRSI.fft_slice_dim(csi_odd), "m_fftz_odd.bin")

println("\n=== T4  MUSICAL coil combination + 1e5 rescale (op_CoilCombineData) ===")
jc = MRSI.coil_combine(csi_odd, ref; ref_point_for_combine=1, combine_method=:musical) .* 1e5
check("coil_combine :musical", jc, "m_coilcomb_odd.bin")

println("\n=== T5  reference-point fallback for a short reference scan ===")
# MRSI_Reconstruction.m:568-572 uses point 1 when the reference has <= 3 FID
# points; MRSI.jl clamps the requested point to the last available one, so it
# uses point 3. Both variants are compared against MATLAB to show which agrees.
ref3 = read_complex("ref3.bin")
jc3_asis = MRSI.coil_combine(csi_odd, ref3; ref_point_for_combine=4, combine_method=:musical) .* 1e5
jc3_pt1 = MRSI.coil_combine(csi_odd, ref3; ref_point_for_combine=1, combine_method=:musical) .* 1e5
check("ref3 MRSI.jl default (clamps to 3)", jc3_asis, "m_coilcomb_ref3.bin")
check("ref3 forced point 1", jc3_pt1, "m_coilcomb_ref3.bin")

println("\n=== T6  the weights stored in WaterReference.mat (MRSI_Reconstruction.m:958) ===")
# The array MATLAB saves as weights.Data and the one coil_combine_weights returns
# have to be the same, or the two pipelines cannot exchange a WaterReference.mat.
jw = MRSI.coil_combine_weights(ref; ref_point_for_combine=4, combine_method=:musical)
check("coil_combine_weights vs stored weights.Data", jw, "m_weights_ref.bin")

println()
npass = count(r -> r[4], results)
@printf("%d/%d parity checks passed\n", npass, length(results))
if npass < length(results)
    println("FAILURES:")
    for r in results
        r[4] || @printf("  %-34s max|d|=%.3e rel=%.3e\n", r[1], r[2], r[3])
    end
end
