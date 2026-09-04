# Validation matrix

What proves an image is shippable. Every setting combination Part1 supports on
this data is run against the built image with data mounts only, and the results
are checked, not merely eyeballed.

## What you need

- a built image (`container/build.sh`)
- one CSI `.dat`
- a T1, converted to MINC, placed at `<out_root>/synthetic_t1.mnc`. Masking from
  an anatomical is the only route Part1 fully supports, so the matrix uses it
  throughout.

## Running it

```
IMAGE=mrsi-pipeline:local ./matrix_7t.sh <dat> <out_root>            # all of it
IMAGE=mrsi-pipeline:local ./matrix_7t.sh <dat> <out_root> julia-gpufit   # one entry
```

Each entry declares the exit status it expects, so a configuration that is
supposed to be refused counts as a pass only when it is actually refused. The
per-run line lands in `<out_root>/matrix_results.tsv`.

The LCModel entries take roughly an hour each and the `-Q` entries a few
minutes, so the deep-fitting subset is what to run while iterating.

## Checking the results

```
python check_b0_once.py <out_root>
```

Two questions, both answered from what the runs left behind:

- **Was the field correction applied exactly once?** Several stages can apply
  it. Part1 corrects before the WALINET removal when `-0` is given, because that
  model is trained on corrected data; the deep fitting corrects when nothing has
  yet. deepmrsi records which of those happened in its `ProcessingApplied`
  entry, so the count is readable rather than inferred. Two corrections leave
  the FIDs shifted by twice the field, which no output announces.

- **Do the runs agree on the field?** `B0map_Hz.nii.gz` is derived from the same
  reference scan by the same code whichever stage applies the correction, so
  every run of one dataset must emit the same numbers. A run that differs has
  read a different reference or scaled it differently.

## Comparing the two reconstructions

`-A Patref` is implemented twice, in `MRSI_Reconstruction.m` and in
`apply_b0_patref.py`, so the MATLAB and the Julia route can be checked against
each other on the field map both write:

```
IMAGE=mrsi-pipeline:local ./matrix_7t.sh <dat> <out_root> matlab-patref-gpufit
IMAGE=mrsi-pipeline:local ./matrix_7t.sh <dat> <out_root> julia-patref-matlab-gpufit
python compare_b0_maps.py <out_root>/matlab-patref-gpufit <out_root>/julia-b0-gpufit
```

The mode on `-S` matters. `-S auto` follows the online scanner route and corrects
the frequency drift the protocol asks for, which the MATLAB reconstruction does
not do at all; `-S "auto,matlab"` reproduces MATLAB instead. Comparing the two
reconstructions without matching the mode measures that difference and little
else, since it is larger than everything between them.

Read the result by signal band rather than by the worst voxel. A field map
derived from phase is as noisy as the voxel is quiet, so on a low SNR reference
the extremes describe the noise. On the 7T fixture the two agree to 0.000 Hz
median in the top tenth of voxels by reference signal, with a spread that halves
each time the band tightens.

`b0_noise_floor.py <matlab run> <julia run>` answers the question the difference
alone cannot: how precisely the field is known at all from that reference scan.
The map is a mean of per-step phase differences, so its standard error follows
from their scatter. A difference far below that uncertainty cannot be resolved
from the data, whatever its origin. Note the two reconstructions see the same raw
data, so their errors are correlated and the difference does not have to reach
the noise floor to be noise; the comparison gives a ceiling, not a test.

`run_evidence.sh <run directory>` pulls the handful of lines that say what a
single run actually did out of its log, which is otherwise a hundred thousand
lines long.

## Iterating on a fix

`PART1_SRC` and `DEEPFIRE_SRC` mount a checkout's sources over the image's copy,
which turns a fifteen minute rebuild into nothing. Both print a warning, because
a run made with either set says nothing about the image as shipped: the
acceptance run is the one with data mounts only.

```
PART1_SRC=<Part1 checkout> DEEPFIRE_SRC=<MRSIdeepFIRE checkout>/python-ismrmrd-server/DEEP_CRT_MRSI/install \
    ./matrix_7t.sh <dat> <out_root> julia-b0-gpufit
```

Do not edit a mounted file while a run is in flight. Bash reads a script as it
executes it, and a mid-run edit surfaces as a syntax error at a line that is
perfectly valid.
