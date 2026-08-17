# Staging the WALINET weights

The image is handed to the collaborator as a `docker save` tarball or an
Apptainer `.sif`, so the WALINET weights have to be **inside** it. Nothing is
fetched or mounted at run time. This directory is where the weights that are
not in any git repository are dropped before the build; the Dockerfile bind
mounts it from the build context and `container/install_walinet_models.sh`
puts each model where the `walinet` package looks for it.

## The three models

| Model name | Installed in the image as | You have to stage it |
|---|---|---|
| `legacy_7T` | `/opt/walinet_models/` (the models root) | **no** |
| `final_7T` | `/opt/walinet_models/7T_Final` | yes, about 1 GB |
| `final_3T` | `/opt/walinet_models/3T_Final` | yes |

The names in the first column are what `walinet` selects by: `MODEL_LAYOUTS` in
`walinet/package_config.py`, and `--walinet_model` on `deepmrsi.py`. The middle
column is the directory that table maps each name to, which is why the staging
directory names and the installed directory names differ.

`legacy_7T` needs no action at all. It is tracked in MRSIdeepFIRE, so it
arrives with the pinned checkout and is selectable in every image.

## What to stage, and where

Drop the complete model directories here, named exactly:

```
container/walinet_models/final_7T/
container/walinet_models/final_3T/
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

`legacy_7T`'s own layout is the older one, a flat checkpoint next to
`models/config.json`, with no `run_summary.txt` and no `configs/`. That is
correct and not a half-installed model, and the build validates it against the
legacy rule.

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

`legacy_7T`'s checkpoint is exactly **1,790,434 bytes** (it is the model shipped
at MRSIdeepFIRE tag `v1.4.0`, where it is named `walinet_7T.pt`; on later refs
the same bytes are `model_best.pt`). A different size means the checkout or the
copy is wrong.

```bash
docker run --rm mrsi-pipeline:local \
    stat -c '%s %n' /opt/walinet_models/model_best.pt
```

`final_7T`'s `model_best.pt` is roughly 1.0 GB. Copies over network drives
truncate silently, so compare the byte count against the source before you
build, not the rounded size:

```bash
find container/walinet_models -name '*.pt' -printf '%s %p\n'
```

## Building

Today's build, with only `legacy_7T` available, is the default and needs no
argument:

```bash
./container/build.sh
```

The image for the collaborator must demand all three, so a forgotten staging
step fails the build instead of shipping a broken image:

```bash
REQUIRE_WALINET_MODELS=all ./container/build.sh
```

`REQUIRE_WALINET_MODELS` also takes a comma separated list, for example
`legacy_7T,final_7T`. Whatever is staged is validated in every build, required
or not: a half-copied `final_7T` fails even the permissive default.

## Untested

The staging path has **never been run with the real `final_7T` or `final_3T`
weights** - neither was available when this was written. It was verified only
against fixture directories with the right file names, plus `bash -n` and
`docker build --check`. Expect the first real staged build to be the one that
proves it.
