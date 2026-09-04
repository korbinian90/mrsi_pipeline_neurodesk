# 7T MRSI pipeline container

A single image that takes a Siemens `.dat` from the Vienna CRT MRSI sequence and
produces metabolite maps. Reconstruction, nuisance removal and fitting are all
inside it; nothing else has to be installed.

This build is for **7T proton data without a water reference**. Other field
strengths and the water-referencing options exist in the code but are not
validated in this image; see "What is not covered" at the end.

## Load it

```bash
gunzip -c mrsi-pipeline_7t-rc5.tar.gz | docker load
docker run --rm mrsi-pipeline:7t-tom2 mrsi-versions
```

The tarball is TARBALL_SIZE_PLACEHOLDER. Check it arrived intact before loading,
since a truncated transfer fails in confusing ways much later:

```bash
sha256sum mrsi-pipeline_7t-rc5.tar.gz
# TARBALL_SHA256_PLACEHOLDER
```

`mrsi-versions` prints the four source commits the image was built from, the
MATLAB Runtime, the WALINET models present and the default fitter. Quote its
output in any question about a result. The three values it labels as online
route defaults are the scanner route's; the command line below sets all three
itself, through `-L`, `-A` and `-Q`.

With Apptainer instead of Docker:

```bash
apptainer build mrsi-pipeline.sif docker-archive://mrsi-pipeline_7t-rc5.tar.gz
```

## How this image was built

Four repositories, pinned to commits rather than branches so the image can be
rebuilt exactly. `mrsi-versions` inside the image reports the same four values,
so a result can always be traced back without consulting this file.

```bash
IMAGE=mrsi-pipeline:7t-tom2  DEEPFIRE_REF=2aea8328c9f4bcb45c62e91bfa7a3a0f79bd39cc  PART1_REF=f42ea63ea706a870fd734c8719827190b972deac  PART2_REF=0f4ffe3b4bd4aaade4800ca2710f67783676523f  MRSIJL_REF=2a80c779417fdc6680e9f9ff37178e40b75857ff  REQUIRE_WALINET_MODELS=7T  TORCH_INDEX_URL=https://download.pytorch.org/whl/cu118  ./container/build.sh
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
  mrsi-pipeline:7t-tom2 \
  Part1_ProcessMRSI.sh \
    -c /dats/meas_MIDxxxxx.dat \
    -o /out/run1 \
    -b /opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/forD/data/basis/fid_1.300000ms.basis \
    -j /opt/Part1/ControlFiles/LCModel_Control_7T_3D_CRT_test_v1.m \
    -S auto \
    -L "WALINET,7T" \
    -A Patref \
    -Q gpufit \
    -t /out/anat.mnc
```

* `-c` the CSI `.dat`.
* `-o` the output directory, under the mounted `/out`.
* `-b` the LCModel basis, `-j` the LCModel control file. Both are inside the
  image at the paths above; they are only needed for the LCModel route but are
  read either way.
* `-L "WALINET,7T"` removes water and lipids, `-A Patref` aligns the spectra first,
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

Check the GPU is actually visible before starting a long run, because the
fallback is silent:

```bash
docker run --rm --gpus all mrsi-pipeline:7t-tom2 mrsi-versions
```

`CUDA visible True` means the fitting will use it. `False` on a machine that has
a GPU almost always means the driver is older than the CUDA 11.8 build of torch
needs. The run still completes, correctly, just far slower.

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

**Frequency alignment**, `-A`: one flag, one correction, whichever stages a
configuration chains together. `-A Patref` measures the field shift from the
reference scan, the way the online scanner pipeline does, so it needs no second
acquisition; it is applied to the finished reconstruction, before WALINET, whose
model was trained on corrected data. On the fixture it lowers the CRLB of every
metabolite and raises the amplitudes, which is the signature of a real frequency
alignment rather than a rescaling.

The other methods, `-A Alignment` and `-A "Alignment,<path>"`, run inside the
MATLAB reconstruction and need `-S` dropped. Whichever one runs, the fitting step
is told the data already carries the correction and does not apply a second one.
Off by default; without `-A`, `-Q` still corrects on its own, as it always has.

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

### What the numbers in deepMRSI mean

Every map except the field map is multiplied by 1000 on the way out, so read the
stored values as thousandths. `deepMRSI/meta.json` says the same thing per map
type and is the machine-readable version of this table.

| file | contains |
|---|---|
| `NAA.nii.gz` | the fitted amplitude, in the raw units of the input data, x1000 |
| `NAA_tCr.nii.gz` | that amplitude over tCr, x1000, so 1267 means 1.267 |
| `NAA_crlb.nii.gz` | the **relative** CRLB, sigma over amplitude, x1000, so 190 means 19% |
| `B0map_Hz.nii.gz` | the measured field map, in hertz, not scaled. Written whether or not the correction was applied, so two runs can be compared on it |

**The CRLB maps are relative in this build.** The previous image stored an
absolute standard deviation in the fitter's internal units, which had to be
divided by the amplitude map before it read as a percentage. That division is
now done for you, and a threshold written against the old maps does not carry
over.

**Amplitudes are in the raw units of the input data.** The previous image left
the fitter's internal normalisation in place, so absolute amplitudes from the
two images differ by a per-dataset scalar and are not comparable. Ratio maps
and the relative CRLBs are unaffected: the scalar cancels in both. `Fits`,
`Baselines` and `Spectra_window` moved with the amplitudes.

## What has been checked

Sixteen configurations on a 16x16x5, 840-point fixture, run against this image with
**data mounts only**, so what was tested is what ships.

| | LCModel | gpufit | dlfit |
|---|---|---|---|
| Julia, no decontamination | 1280/1280 | 46 maps | 52 maps |
| Julia, L2 | 1280/1280 | 46 maps | 52 maps |
| Julia, L1 | 1280/1280 | - | - |
| Julia, WALINET 7T | 1280/1280 | 46 maps | 52 maps |
| Julia, WALINET 7T with `-A Patref` | - | 46 maps | - |
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
this build is for, run with `-S auto -A Patref -L "WALINET,7T" -Q gpufit`. Exit 0
in 107 minutes on one GPU, 46 maps. The crop fired: 864 acquired, 840 into the
removal, the original kept beside it as `CombinedCSI_beforeWalinet.mat`, and the
fits reporting 840.

TO BE REDONE BEFORE THIS SHIPS: the fit quality from that run is not quoted here.
It came from a build in which this configuration applied the field correction
twice, once in the reconstruction and once in the fitting, so its CRLBs describe
data shifted by twice the measured field. The run has to be repeated on this
build before any number from it is used.

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
