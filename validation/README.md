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
