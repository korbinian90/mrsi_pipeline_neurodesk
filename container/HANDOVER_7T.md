# 7T MRSI pipeline container

A single image that takes a Siemens `.dat` from the Vienna CRT MRSI sequence and
produces metabolite maps. Reconstruction, nuisance removal and fitting are all
inside it; nothing else has to be installed.

This build is for **7T proton data without a water reference**. Other field
strengths and the water-referencing options exist in the code but are not
validated in this image; see "What is not covered" at the end.

## Load it

```bash
gunzip -c mrsi-pipeline_7t.tar.gz | docker load
docker run --rm mrsi-pipeline:7t-tom mrsi-versions
```

`mrsi-versions` prints the four source commits the image was built from, the
MATLAB Runtime, the WALINET models present and the default fitter. Quote its
output in any question about a result.

Its last three lines, `walinet model`, `fitting` and `apply_walinet`, come from the
package configuration and describe the **online scanner route only**. The command
line below takes all three from `-L`, `-0` and `-Q` instead, so `apply_walinet
True` there does not mean this pipeline applies WALINET unless asked. It does not:
without `-L WALINET` no removal runs.

With Apptainer instead of Docker:

```bash
apptainer build mrsi-pipeline.sif docker-archive://mrsi-pipeline_7t.tar.gz
```

## How this image was built

Four repositories, pinned to commits rather than branches so the image can be
rebuilt exactly. `mrsi-versions` inside the image reports the same four values,
so a result can always be traced back without consulting this file.

```bash
IMAGE=mrsi-pipeline:7t-tom  DEEPFIRE_REF=7cc1f1037aa3f0fd2fe1b5e70bed33fb680cc116  PART1_REF=f42ea63ea706a870fd734c8719827190b972deac  PART2_REF=0f4ffe3b4bd4aaade4800ca2710f67783676523f  MRSIJL_REF=21c21930df4f802d2bae2e6e4b348b29c394347a  REQUIRE_WALINET_MODELS=7T  TORCH_INDEX_URL=https://download.pytorch.org/whl/cu118  ./container/build.sh
```

`REQUIRE_WALINET_MODELS=7T` asserts the 7T weights are present. It does not
exclude the 3T ones: the installer stages every model it finds, so both ship.
Only the 7T route is validated here.

`TORCH_INDEX_URL` selects the CUDA 11.8 build of torch. Without it the image gets
the CPU wheel, which reports no CUDA device even on a GPU host.

## Run one dataset

```bash
docker run --rm --gpus all \
  -v /path/to/dats:/dats:ro \
  -v /path/to/output:/out \
  mrsi-pipeline:7t-tom \
  Part1_ProcessMRSI.sh \
    -c /dats/meas_MIDxxxxx.dat \
    -o /out/run1 \
    -b /opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/forD/data/basis/fid_1.300000ms.basis \
    -j /opt/Part1/ControlFiles/LCModel_Control_7T_3D_CRT_test_v1.m \
    -S auto \
    -L "WALINET,7T" \
    -0 \
    -Q gpufit \
    -t /out/anat.mnc
```

* `-c` the CSI `.dat`.
* `-o` the output directory, under the mounted `/out`.
* `-b` the LCModel basis, `-j` the LCModel control file. Both are inside the
  image at the paths above; they are only needed for the LCModel route but are
  read either way.
* `-L "WALINET,7T"` removes water and lipids, `-0` aligns the spectra first,
  and `-Q gpufit` fits what comes out. The three are independent: drop any of
  them and the rest still work.
* `-S auto` selects the Julia reconstruction. Leave it off for the MATLAB one.
  Either way the MATLAB steps run as compiled binaries against the Runtime, which
  is the only MATLAB this image has; `-K` selects that explicitly and is the
  default here, so it does not have to be passed.
* `-t` an anatomical image for the mask. Without it, use `-m "bet,-f 0.65 -g 0.1"`
  to mask from the reference scan instead.

`--gpus all` is what makes this practical: on a full volume the fitting is
minutes on a GPU and hours on a CPU. Without a visible device the same algorithm
runs on the CPU and says so in the log; it does not change method.

## The settings that matter

**Reconstruction.** `-S auto` for Julia, omit for MATLAB. Julia uses less memory
and is the route everything else here was validated against.

**Lipid and water removal**, `-L`:

| | |
|---|---|
| omitted | no decontamination |
| `-L "L2,1e-3"` | L2 regularization after Bilgic et al. The value is data dependent; try a few |
| `-L "L1,10"` | L1 regularization, 10 iterations |
| `-L "WALINET,7T"` | the neural network removal |

`-L` chooses the decontamination and nothing else. WALINET combines with any
fitter, exactly as L1 and L2 do.

**Fitting**, `-Q <fitter>`:

| | |
|---|---|
| omitted | LCModel |
| `-Q gpufit` | the GPU fitter. Maps go to `<out>/deepMRSI` as NIfTI |
| `-Q dlfit` | the deep-learning fitter. 840-point grid only |

**B0 correction**, `-0`: applies the measured field shift to the spectra directly
before WALINET, which is the order the online scanner pipeline uses. It has no
effect unless WALINET runs. On the fixture it lowers the CRLB of every metabolite
and raises the amplitudes, which is the signature of a real frequency alignment
rather than a rescaling. Off by default, so a run without it reproduces earlier
results.

WALINET needs `-S auto`: the MATLAB reconstruction has no WALINET, so asking for
it without the Julia route stops rather than quietly reconstructing with no
decontamination.

## FID length

The 7T WALINET model is trained for 420 to 840 acquired points. A longer
acquisition is **cropped to 840 before the removal**, and the spectra, the grid
and the fits then all describe those 840 points. The discarded tail is late FID,
which is water dominated, so it is exactly what the removal would have taken out;
splicing it back would undo the removal. A 864-point acquisition loses 24 samples
this way, 2.8% of the readout.

Runs without WALINET keep the full acquisition.

## Output

```
<out>/spectra/       LCModel .table and .ps per voxel, and the .RAW/.control inputs
<out>/deepMRSI/      metabolite maps, CRLB maps and ratio maps as NIfTI, when -Q ran
<out>/maps/          the mask, the magnitude image and the MINC templates
<out>/log.txt        everything the run printed
```

`deepMRSI/CITATIONS.txt` lists what to cite for the components that ran.

## What has been checked

Sixteen configurations on a 16x16x5, 840-point fixture, run against this image with
**data mounts only**, so what was tested is what ships.

| | LCModel | gpufit | dlfit |
|---|---|---|---|
| Julia, no decontamination | 1280/1280 | 46 maps | 52 maps |
| Julia, L2 | 1280/1280 | 46 maps | 52 maps |
| Julia, L1 | 1280/1280 | - | - |
| Julia, WALINET 7T | 1280/1280 | 46 maps | 52 maps |
| Julia, WALINET 7T with `-0` | - | 46 maps | - |
| MATLAB, no decontamination | 1280/1280 | - | - |
| MATLAB, L2 | 1280/1280 | - | - |

Also checked: `-t` with `-m bet`, which fits the brain-extracted mask rather than
the full grid and returns 44 of 44 voxels.

Map counts no longer depend on the decontamination, so a script that reads
`deepMRSI/NAA.nii.gz` finds the same name whichever `-L` ran.

Two refusals behave as intended: WALINET without `-S`, and the 3T model on 7T
data. Both stop with a message naming the mismatch instead of reconstructing
without decontamination or removing against the wrong field.

The reconstruction was checked against MRSI.jl rather than assumed: `julia_csi.raw`
from this container is **bit-identical** to a direct `MRSI.reconstruct` with the same
keywords, 0 of 1,075,200 elements differing, and `CombinedCSI.mat` holds that same
array unchanged. The B0 map on the fixture has a median of -1.7 Hz and a 5-95% range
of -41 to +44 Hz, which is the right order for 7T.

**What that fixture cannot tell you.** It has `n_channels = 1`, a single-channel
volume coil, so MUSICAL coil combination never runs in any of the sixteen. It is
also low SNR, so the CRLBs on it say nothing about fit quality. Both are covered by
the in-vivo runs recorded separately, not by this table.

### In vivo

Two runs on this image, not on the fixture.

**32 channels, 840 points.** Reconstruction bit-identical to a direct
`MRSI.reconstruct` here too, 0 of 3,440,640 elements differing, so the flag mapping
is exact including MUSICAL coil combination.

**58 x 58 x 21, 864 points, 40 GB.** The same shape and readout length as the data
this build is for, run with `-S auto -0 -L "WALINET,7T" -Q gpufit`. Exit 0 in 107
minutes on one GPU, 46 maps, NAA at 19% median CRLB over 12,984 voxels. The crop
fired: 864 acquired, 840 into the removal, the original kept beside it as
`CombinedCSI_beforeWalinet.mat`, and the fits reporting 840.

**The fitter was checked against LCModel** rather than only against itself. On the
same voxels of the same 32-channel dataset, gpufit and LCModel agree to 3 to 8% on
the metabolites either determines well:

| | LCModel | gpufit |
|---|---|---|
| tNAA / tCr | 1.794 | 1.842 |
| NAA / tCr | 1.510 | 1.583 |
| Glu / tCr | 1.202 | 1.309 |
| Tau / tCr | 0.326 | 0.341 |
| GSH / tCr | 0.186 | 0.173 |

Two disagree and are worth knowing before relying on them: `mIns`, where gpufit reads
about twice LCModel, and `Gln`, where it reads about a third. Both are present
whichever way the run is configured, so they belong to the fitter or its basis rather
than to a setting.


## What is not covered

* **Water referencing** (`-w "W1,<dat>"`) is present but not validated in this
  build. It is also mutually exclusive with `-S auto` today.
* **3T.** The 3T WALINET weights ship in the image but the 3T route is not
  validated here. The 3T WALINET model accepts at most 288 points, so selecting
  it for an 840-point 7T acquisition is refused.
* **Deuterium.**
* **Part2** (registration and evaluation) is in the image but was not exercised.
