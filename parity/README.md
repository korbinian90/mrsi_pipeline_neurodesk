# Julia / MATLAB parity harness

Checks that the stages the Julia (`MRSI.jl`) and MATLAB (`Part1`) pipelines are
*supposed* to share produce the same numbers. Both sides are fed byte-identical
inputs and both call the projects' own functions, not reimplementations.

## Running

```powershell
cd parity
$env:PART1_DIR = "C:\path\to\Part1_Reco_LCModel_MUSICAL_Streamlined_Git"
julia --startup-file=no gen_input.jl
matlab -batch "run('$pwd\run_matlab.m')"
julia --startup-file=no compare.jl
```

`PART1_DIR` defaults to a `Part1_Reco_LCModel_MUSICAL_Streamlined_Git` checkout
sitting next to this repository. `MRSI.jl` must be resolvable by Julia, which it
is when it is `Pkg.develop`ed (the standard `~/.julia/dev/MRSI` checkout).

`gen_input.jl` writes deterministic complex arrays into `io/` as flat Float64
(all real parts, then all imaginary parts). MATLAB and Julia are both
column-major and 1-based, so the same bytes reshape to the same array on both
sides with no index juggling.

## What is covered

| test | Julia | MATLAB | result |
|------|-------|--------|--------|
| T1 Hamming window values | `MRSI.hamming_filter` over `range(-0.5,0.5,n)` | `hamming(n)` | identical |
| T2 z-Hamming filter, image domain | `MRSI.hamming_filter_z!` | `HammingFilter(x,[3],100,'OuterProduct',0)` | identical |
| T3 slice-dim FFT convention | `MRSI.fft_slice_dim` | `ifftshift`/`fft`/`fftshift` | identical |
| T4 MUSICAL coil combination + 1e5 | `MRSI.coil_combine(...; :musical)` | `op_CoilCombineData` | identical |
| T5 reference-point fallback | `coil_combine(...; ref_point_for_combine=4)` | `MRSI_Reconstruction.m:568-572` | **differs** |

T1 to T4 agree to floating-point round-off (relative differences of 1e-16,
i.e. the last bit of a double). These are the stages `reconstruct_like_MATLAB_full`
claims to reproduce, and the claim holds.

The analytic reason T1 passes: `range(-0.5, 0.5, n)` gives `r_k = -0.5 + k/(n-1)`,
so `0.54 + 0.46*cos(2*pi*r_k) = 0.54 - 0.46*cos(2*pi*k/(n-1))`, which is exactly
MATLAB's symmetric Hamming window.

## The one real difference (T5)

`MRSI_Reconstruction.m:568-572` picks the coil-combination reference point like
this:

```matlab
if(size(image.Data,4) > 3)
    image.Data = image.Data(:,:,:,4,:);
else
    image.Data = image.Data(:,:,:,1,:);
end
```

so a reference scan with 3 or fewer FID points falls back to point **1**.
`MRSI.jl`'s `coil_combine` instead clamps the requested point to the last
available one:

```julia
pt = max(1, min(ref_point_for_combine, size(refscan, 4)))
```

With a 3-point reference MATLAB uses point 1 and Julia uses point 3, and the
combined result is completely different (relative difference 1.015). Forcing
`ref_point_for_combine=1` reproduces MATLAB to 1.5e-16, which confirms this
single line is the whole cause.

**Not reachable with real data.** Reference scans carry hundreds of FID points
(Tom Shaw's 7T water reference has vecSize 256, the 3T one 512), so the branch
never fires in practice. It is recorded here so the parity claim stays honest
and so a future short-reference dataset does not fail silently.

If it is ever worth closing, the fix matches MATLAB exactly:

```julia
pt = size(refscan, 4) > 3 ? min(ref_point_for_combine, size(refscan, 4)) : 1
```

That was deliberately not applied, because `coil_combine` is shared with the
ICE-parity path (`reconstruct_like_ICE`, default `ref_point_for_combine=5`) and
changing it would alter that path's behaviour for the same unreachable case.

## Caveat

The Signal Processing Toolbox is not installed on this machine, so `hamming()`
is supplied by `shim/hamming.m` using MATLAB's documented symmetric-window
formula. That shim is the only non-project code in the harness; every other
function called is Part1's or MRSI.jl's own. The compiled Part1 binaries bundle
the real toolbox function, so on the container this substitution does not apply.
