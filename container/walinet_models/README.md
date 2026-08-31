# Staging the WALINET weights

The image is handed to the collaborator as a `docker save` tarball or an
Apptainer `.sif`, so the WALINET weights have to be **inside** it. Nothing is
fetched or mounted at run time. This directory is where the weights that are
not in any git repository are dropped before the build; the Dockerfile bind
mounts it from the build context and `container/install_walinet_models.sh`
puts each model where the `walinet` package looks for it.

## The two models

| Model name | Installed in the image as | You have to stage it |
|---|---|---|
| `7T` | `/opt/walinet_models/7T_Final` | yes, about 1 GB |
| `3T` | `/opt/walinet_models/3T_Final` | yes, about 1 GB |

The names in the first column are what `walinet` selects by: `MODEL_LAYOUTS` in
`walinet/package_config.py`, `--walinet_model` on `deepmrsi.py`, and `-Q`'s
second argument in Part1. The middle column is the directory that table maps
each name to, which is why the staging directory names and the installed
directory names differ.

Neither arrives with the pinned checkout. Both are gitignored in MRSIdeepFIRE,
so both have to be staged.

## What to stage, and where

Drop the complete model directories here, named exactly:

```
container/walinet_models/7T/
container/walinet_models/3T/
```

Nothing you put here is committed: `.gitignore` ignores everything except
itself and this README, because the payloads are hundreds of MB.

Each staged directory must contain, because that is what the loader reads:

| Entry | Why it is required |
|---|---|
| `model_best.pt` | the checkpoint every loader defaults to (`model_last.pt` is only a fallback for a missing `model_best.pt`) |
| `run_summary.txt` | selects the "Format 2" loader and supplies `nLayers` / `nFilters` / `in_channels` / `out_channels` |
| `configs/` | the normalization and the acquisition lengths (`n_timepoints`, `min_` / `max_acquired`) that drive the FID-length handling |

A missing `configs/` does **not** fail loudly at run time. It quietly degrades
to the "older model" path and drops the FID-length handling, which is exactly
why the build validates the directory instead of trusting it.

`src/` and `loss.txt` are usually present in these directories and are **not**
needed: `src/` only serves a legacy loader and `loss.txt` is a training log.
Leaving them out keeps the shipped image smaller. `package.sh` and the
MRSIdeepFIRE release workflows exclude both for the same reason.

## Where the weights come from

They live on a private OneDrive, reached with `rclone`:

```
onedrive_mrsi_deep_fire:MRSIdeepFIRE/walinet/7T_Final
onedrive_mrsi_deep_fire:MRSIdeepFIRE/walinet/3T_Final
```

That remote is configured **only** in the MRSIdeepFIRE GitHub Actions
workflows, from the `RCLONE_CONF` repository secret (see
`.github/workflows/docker-build-*.yml`, "Fetch WALINET model from OneDrive").
It is **not** configured on the build machine, and `rclone` is not even
installed there, so the copy is a manual step: fetch the directories however
you normally reach that OneDrive and put them here. The workflows fetch with

```bash
rclone copy "onedrive_mrsi_deep_fire:MRSIdeepFIRE/walinet/7T_Final" <dest> \
    --exclude "src/**" --exclude "loss.txt" -v --transfers 4
```

which is also the right exclude list for staging by hand.

## Checking a copy is not truncated

Each `model_best.pt` is roughly 1.0 GB. Copies over network drives truncate
silently, so compare the byte count against the source before you build, not
the rounded size:

```bash
find container/walinet_models -name '*.pt' -printf '%s %p\n'
```

## Building

`REQUIRE_WALINET_MODELS` defaults to `all`, so a plain build already demands
both models and a forgotten staging step fails the build instead of shipping a
broken image:

```bash
./container/build.sh
```

Narrow it with `none`, or with a comma separated list, for example `7T` for an
image built without the 3T weights:

```bash
REQUIRE_WALINET_MODELS=7T ./container/build.sh
```

Whatever is staged is validated in every build, required or not, so a
half-copied `7T` fails the build even when it was not required.

Check which models an image ended up with:

```bash
docker run --rm mrsi-pipeline:local \
    python3 -c "import walinet.package_config as c; print(c.MODEL_CHOICES)"
```

## Status

The staging path has been run with the real weights. Both models are staged
here, about 1.07 GB each with `run_summary.txt` and `configs/` present, and
`mrsi-pipeline:matlab-dev` was rebuilt from them on 2026-08-30 with
`REQUIRE_WALINET_MODELS=7T,3T`. It reports `('7T', '3T', 'off')` and carries
both `7T_Final` and `3T_Final`.

That rebuild is also what retired the old model names. An image built from a
`DEEPFIRE_REF` older than the renaming still reports the three pre-rename names
and cannot select `7T` or `3T` at all, so check `MODEL_CHOICES` as above before
trusting a WALINET result from an image you did not build yourself.
