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

With Apptainer instead of Docker:

```bash
apptainer build mrsi-pipeline.sif docker-archive://mrsi-pipeline_7t.tar.gz
```

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
    -Q gpufit 7T \
    -t /out/anat.mnc
```

* `-c` the CSI `.dat`.
* `-o` the output directory, under the mounted `/out`.
* `-b` the LCModel basis, `-j` the LCModel control file. Both are inside the
  image at the paths above; they are only needed for the LCModel route but are
  read either way.
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
| `-L "WALINET,7T"` | the neural network removal, then LCModel fits the cleaned spectra |

**Fitting**, `-Q <fitter> <walinet model>`:

| | |
|---|---|
| omitted | LCModel |
| `-Q gpufit 7T` | the GPU fitter, with WALINET removal first. Maps go to `<out>/deepMRSI` as NIfTI |
| `-Q gpufit off` | the GPU fitter, no WALINET |
| `-Q dlfit 7T` | the deep-learning fitter. 840-point grid only |

`-L WALINET` and `-Q <fitter> 7T` both apply WALINET. Asking for both is refused
rather than removing water and lipids twice. Use `-L` when you want LCModel to do
the fitting and `-Q` when you want the deep fitter.

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

## What is not covered

* **Water referencing** (`-w "W1,<dat>"`) is present but not validated in this
  build. It is also mutually exclusive with `-S auto` today.
* **3T.** The 3T WALINET weights ship in the image but the 3T route is not
  validated here. The 3T WALINET model accepts at most 288 points, so selecting
  it for an 840-point 7T acquisition is refused.
* **Deuterium.**
* **Part2** (registration and evaluation) is in the image but was not exercised.
