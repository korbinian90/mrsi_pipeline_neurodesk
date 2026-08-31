# Local MRSI processing container

A privately built container for one external collaborator and the Vienna
developers. It is **not** published to Neurodesk and **not** built by public CI.
That is what allows it to clone the private repositories directly at build time
and to require no public release of code or model weights.

The image does not vendor a merged copy of the pipeline. It pins four upstream
repositories, so upstream work arrives by bumping one build argument:

| Build arg | Repository | Path in the image |
|---|---|---|
| `PART1_REF` | `phipzl/Part1_Reco_LCModel_MUSICAL_Streamlined_Git` | `/opt/Part1` |
| `PART2_REF` | `phipzl/Part2_Registration_Evaluation_Streamlined_Git` | `/opt/Part2` |
| `DEEPFIRE_REF` | `korbinian90/MRSIdeepFIRE` | `/opt/deepmrsi` |
| `MRSIJL_REF` | `korbinian90/MRSI.jl` | `/opt/MRSI.jl` |

## Prerequisites

* Docker with BuildKit (Docker 23+ enables it by default; `build.sh` sets
  `DOCKER_BUILDKIT=1` regardless).
* A running SSH agent holding a key with read access to all four repositories.
  The agent is forwarded into the build with `--ssh default` and is available
  only for the duration of the clone steps. No key material is written into the
  image.
* Disk: the build downloads roughly 6 GB (the MATLAB Runtime R2023a installer
  alone is 4.7 GB) and the finished image is expected to land in the high
  single-digit GB range.
  This is an estimate. The image has not been built yet, see "Not yet verified".

## Build

```bash
./container/build.sh
```

or by hand:

```bash
DOCKER_BUILDKIT=1 docker build --ssh default \
    -f container/Dockerfile -t mrsi-pipeline:local container
```

### Bumping a single repository

Each ref is an independent build argument, so picking up upstream work in one
repository leaves the other three untouched:

```bash
PART1_REF=3f2a1c9 ./container/build.sh          # new Part1 only
DEEPFIRE_REF=v1.4.0 ./container/build.sh        # new deepmrsi only
```

The defaults live in the Dockerfile's `ARG` lines and nowhere else: `build.sh`
passes `--build-arg` only for the variables you actually set. They are the four
upstream default branches, which are convenient for development but are not
reproducible. For anything you hand to the collaborator, pass explicit commit
SHAs and note them down. After a build, the image can tell you what it actually
contains:

```bash
docker run --rm mrsi-pipeline:local bash -lc \
  'for r in /opt/Part1 /opt/Part2 /opt/deepmrsi /opt/MRSI.jl; do
       echo -n "$r "; git -C $r rev-parse HEAD; done'
```

### Building with the target-A work

Every ref defaults to the branch that carries its half of the work, so a plain
`./build.sh` produces the shippable image. Nothing has to be overridden.

| repository   | default ref                              | carries                                      |
|--------------|------------------------------------------|----------------------------------------------|
| Part1        | `neurodesk`                              | `-S` Julia dispatch, JSON sidecar, `-Q` path |
| Part2        | `neurodesk`                              | `MNI_ATLAS_DIR` portability                  |
| MRSIdeepFIRE | `claude/container-fitting-selection-20260817` | WALINET selector, fitting selector, MRSI subtree |
| MRSI.jl      | `claude/optional-patrefscan-20260818`    | optional PATREFSCAN, water-reference weights |

`neurodesk` is master plus a merge of the feature branches, so it is a strict
superset of upstream. The unmerged review branches are `julia-integration`
(the `-S` wiring alone) and `deepmrsi-fitting` (the `-Q` path on top), both
pushed to phipzl, plus `container-portability` on Part2.

Two couplings are load-bearing when bumping refs:

- `MRSIJL_REF` and the `offline_pipeline/MRSI` subtree inside `MRSIdeepFIRE`
  must name the same MRSI.jl commit. The image installs MRSI.jl twice, at
  `/opt/MRSI.jl` for Part1 and as the subtree for the deepmrsi offline
  pipeline. Divergence is invisible until the two paths return different
  numbers. Re-sync with
  `git subtree pull --prefix=offline_pipeline/MRSI mrsi-upstream <ref> --squash`.
- The WALINET model names selectable at run time come from `MODEL_LAYOUTS` in
  `walinet/package_config.py`, which only exists on the MRSIdeepFIRE ref above.

Once the MRSI.jl and MRSIdeepFIRE branches are merged to their default
branches, reset the two refs to `main` and `master` and re-run the subtree
pull, so the image tracks default branches again.

## Exporting for the collaborator

Measured on the first verified build: **43.9 GB** unpacked in the local image
store, **11.9 GB** as a `docker save | gzip -1` stream. Slower compression
gains a little more. For comparison, the published `vnmd/mrsiproc_0.2.0` is
25.49 GB on Docker Hub, which is also a compressed figure, so this image is
roughly half the size to ship. Do not compare the 43.9 GB against that number:
one is unpacked and the other is compressed.

Two layers dominate and neither is removable without a bigger change: the
MATLAB Runtime (10.3 GB, needed by every compiled binary) and the FSL base
image (about 12.4 GB, of which the pipeline uses little more than `bet`).
Swapping the base image is the only remaining large saving.

Docker tarball:

```bash
docker save mrsi-pipeline:local | gzip > mrsi-pipeline_local.tar.gz
# on the receiving machine
gunzip -c mrsi-pipeline_local.tar.gz | docker load
```

Apptainer / Singularity, either straight from the local daemon:

```bash
apptainer build mrsi-pipeline.sif docker-daemon://mrsi-pipeline:local
```

or from the tarball on a machine without Docker:

```bash
apptainer build mrsi-pipeline.sif docker-archive://mrsi-pipeline_local.tar.gz
```

Apptainer mounts `$HOME` and the current directory by default and runs as the
calling user, so nothing in the image may assume root. Everything the pipeline
writes to lives under the working directory you pass in.

## What is in the image, and what was removed

Carried over from the Neurodesk recipe `recipes/mrsiproc/build.yaml` (v0.2.0):

* **MATLAB Runtime R2023a**, about 4.7 GB of installer download and mandatory.
  Every compiled binary under `Part1/Matlab_Compiled` and
  `Part2/Matlab_Compiled` was built against it: both `Matlab_Compiled`
  `readme.txt` files ask for R2023a, and both `InstallProgramPaths.sh` scripts
  put `/opt/MATLAB_Runtime_R2023a/R2023a/...` on `LD_LIBRARY_PATH`, which is
  the layout the image installs. Note that R2023a and later use a
  release-named subdirectory rather than the older `v9xx` one.
* **MINC toolkit 1.9.15** plus the ICBM152 09a/09c models. The whole pipeline
  speaks MINC.
* **FSL**, from the `vnmd/fsl_6.0.7.1` base image. `bet` is the brain
  extraction used by both the pipeline and the deepmrsi masking step.
* **LCModel 6.3 core**, the `lcmodel` binary that `RunLCModel.sh` calls.
* **dcm2niix**, kept deliberately. `dcm2mnc` cannot convert modern XA60
  DICOMs, so the anatomical conversion path in `create_mask.sh` goes through
  dcm2niix and `nii2mnc`.
* **Julia**, for the MRSI.jl reconstruction path.

Removed, with the reason:

* **FreeSurfer 7.4.1 and its X11/csh apt prerequisites (about 9.5 GB).** The
  only consumer was `Part2/Bash_Functions/Segmentation/synthseg.sh`, which is
  being deleted from Part2. There is not a single FreeSurfer string in any of
  the 11 unique compiled MATLAB binaries in this repository: 4 under
  `Part1/Matlab_Compiled`, 4 under `Part2/Matlab_Compiled` and 3 under
  `matlab_compiled` (11 distinct checksums, no duplicates among them).
* **HD-BET and its CUDA torch / nnU-Net closure (about 6.3 GB).** Zero matches
  repo-wide; brain extraction goes through FSL `bet`.
* **The five LCModel basis-set zips.** Nothing references
  `.lcmodel/basis-sets`; the basis always arrives through the `-b` argument.
* **Unused apt packages** (`unrar`, `gv`, `vim`, `nano`, `openjdk-8-jre`,
  `dbus-x11`) and the LCModel GUI profile defaults, which only matter for the
  interactive GUI.

Added:

* **CPU-only PyTorch** (`torch 2.3.1+cpu`, about 190 MB, not the CUDA wheel) in
  a dedicated venv at `/opt/venv`.
* **The deepmrsi Python packages** installed editable from the pinned
  MRSIdeepFIRE checkout: `deep_crt_mrsi`, `mrs_utils`, `forD`, `forD_gpu_fit`,
  `walinet`.
* **mritools 4.5.3** at `/opt/mritools`, because `deep_crt_mrsi/bet_mask.py`
  calls `/opt/mritools/bin/makehomogeneous` by absolute path.
* **MRSI.jl**, `Pkg.develop`ed into the shared depot `/opt/julia_depot`, plus
  an instantiated deepmrsi `offline_pipeline` project.

Environment set by the image: `JULIA_MRSI_PKG=/opt/MRSI.jl`,
`JULIA_DEEPMRSI_PKG=/opt/deepmrsi/offline_pipeline`, `MNI_ATLAS_DIR`,
`MatlabFunctionsFolder`, `MATLAB_RUNTIME_ROOT`, and `/opt/Part1` plus
`/opt/Part2` on `PATH`.

## Fitting backends

The fitter is a setting, read from
`/opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/deep_crt_mrsi/package_config.json`:

| `"fitting"` | Behaviour |
|---|---|
| `auto` | Use the configured `default_fitting` (currently `gpufit`). |
| `dlfit` | forD. Refuses anything that is not the 7T CRT grid (840 points, 360 us dwell, 297.22 MHz) instead of silently zero-padding onto a mismatched basis. |
| `gpufit` | forD_gpu_fit, the regularized fitter. Runs on CUDA when a device is visible, otherwise on the CPU. |
| `off` | Emit spectra, no metabolite maps. |

Selection is deliberately not a CUDA probe: the presence of a GPU changes the
device a fitter runs on, never the algorithm, so the same protocol produces the
same maps everywhere.

To change it in a built image, edit that JSON (the packages are installed
editable, so the checkout is the source of truth) or mount a modified copy over
it.

## WALINET models

The weights are **baked into the image**. The collaborator gets a tarball or a
`.sif` and runs it: nothing is fetched from a network and nothing has to be
mounted in.

`walinet` resolves its weights as
`<walinet package>/models/<model_relative_path>`, and the package has no
setting for that location. So at build time the image moves that directory to
`/opt/walinet_models`, makes it world writable and symlinks it back into the
package. The path is a build argument (`--build-arg WALINET_MODEL_DIR=...`),
not a runtime variable: it only decides where the symlink points while the
image is built, so setting it on `docker run` would do nothing and the image
does not export it.

| Model | In the image | Staged by hand |
|---|---|---|
| `7T` | `/opt/walinet_models/7T_Final` | yes, about 1 GB |
| `3T` | `/opt/walinet_models/3T_Final` | yes, about 1 GB |

Neither is in a git repository: drop the directories into
`container/walinet_models/7T/` and `container/walinet_models/3T/` before
building. That directory's [README](walinet_models/README.md) has the exact
file list, where the weights come from, and how to spot a truncated copy.

Every build validates what is installed, layout aware, and stops with the
names of the missing files rather than producing an image whose model
selection dies mid-reconstruction. `REQUIRE_WALINET_MODELS` says which models
the build insists on:

```bash
./container/build.sh                          # default: all, so both required
REQUIRE_WALINET_MODELS=7T ./container/build.sh    # only 7T's absence is fatal
```

Whatever is staged is validated either way, so a half-copied `7T` fails even
the narrowed setting.

This variable does **not** decide what the image contains, only which absences
stop the build: everything staged is installed regardless. Dropping a model from
the image means not staging it, which the
[staging README](walinet_models/README.md) spells out.

If no WALINET weights are wanted at all, set `"apply_walinet": false` in the
`deep_crt_mrsi` `package_config.json` and the run skips water/lipid removal.

## CPU and GPU

The default build installs the CPU-only PyTorch wheel and **no CUDA runtime**.
Be aware of what that means concretely:

* On a machine with no GPU, `gpufit` runs the identical algorithm on the CPU.
  Correct, roughly an order of magnitude slower.
* On a GPU machine, the default CPU wheel still reports
  `torch.cuda.is_available() == False`, even with `libcuda` visible. A CPU-only
  wheel contains no CUDA kernels. To get acceleration on the same code path,
  rebuild with the CUDA wheel index and run with device access:

  ```bash
  TORCH_INDEX_URL=https://download.pytorch.org/whl/cu118 ./container/build.sh
  docker run --gpus all ...        # or: apptainer run --nv ...
  ```

  That adds roughly 2.5 GB. The host still needs its own NVIDIA driver; nothing
  in the image provides one.

## Verifying a built image

```powershell
docker run --rm -v "${PWD}/container:/smoke:ro" mrsi-pipeline:local bash /smoke/smoke_test.sh
```

`smoke_test.sh` checks that every component is present *and runs*, and exits
non-zero if anything fails. It covers the external tools, both Julia entry
points, the deepmrsi imports, the fitting backends, the WALINET model names,
the compiled MATLAB binaries, and that the container environment survives
being sourced through `InstallProgramPaths.sh`.

## What the first build turned up

All four were silent failures: the image built and looked complete.

1. **Julia segfaulted under the MATLAB Runtime.** The runtime ships its own
   `libstdc++`/`libgcc_s` in `sys/os/glnxa64`, that directory is on
   `LD_LIBRARY_PATH`, and Julia bound to those instead of its own and died with
   SIGSEGV during precompilation. `julia` is therefore a wrapper that strips
   `MATLAB_Runtime` entries. This was not only a build problem: Part1's
   `InstallProgramPaths.sh` puts the same directory on the path before calling
   `run_julia_reco.jl`, so the Julia reconstruction would have died at run time
   too. The build keeps a probe that records the unwrapped binary still failing,
   so the wrapper does not become folklore.
2. **The compiled MATLAB binaries are not in git.** Both repositories gitignore
   `Matlab_Compiled/`, so cloning them can never produce the binaries the
   pipeline executes. They are vendored in this repository and copied in. This
   also broke the *Julia* route, because `run_matlab.sh` refuses to use the
   Julia output unless `julia_write_lcm_files` is present.
3. **`Part1/MatlabFunctions/MRSIMatlabFunctions` is a submodule** and came up
   empty, so the entire MATLAB function library was missing. The clone now runs
   `submodule update --init --recursive`.
4. **`deep_crt_mrsi.deepmrsi` imports `ismrmrd_server.mrdhelper`**, which is a
   plain directory in the checkout rather than an installed package. Part1's
   `run_deepmrsi.py` imports exactly that module, so the whole `-Q` route failed
   at import. Fixed with `PYTHONPATH`, asserted at build time.

## Not yet verified

Written honestly, because none of the following is settled:

1. **End to end has been proven on a fixture, and the fixture cannot exercise
   coil combination.** Part1 ran DAT to LCModel fits on a 16x16x5x840 fixture in
   `mrsi-pipeline:matlab-dev`, across eleven reconstruction, decontamination and
   fitting configurations. That fixture has `n_channels = 1`, a single-channel
   volume coil, so MUSICAL never runs and none of those eleven results says
   anything about coil combination. Nothing of production size has been run
   either, in this image or that one.
2. **The GPU variant has no clean build from this Dockerfile.** The image in
   use is `mrsi-pipeline:gpufix`, an overlay adding the matching-distro
   mritools on top of an older `mrsi-pipeline:gpu`. Both of its fixes are in
   the canonical Dockerfile, but a build straight from it is unproven.
3. **`MNI_ATLAS_DIR` is still not consumed by Part2's `coregistration.sh`**,
   which hardcodes `/net/mri.meduniwien.ac.at/...`. The variable is set and the
   atlas is present so upstream can start reading it.
4. **`JULIA_VERSION` (1.12.6) was read from the MRSIdeepFIRE
   `offline_pipeline/Manifest.toml`.** If `DEEPFIRE_REF` moves to a manifest
   with another `julia_version`, bump the arg too, or Julia re-resolves the
   manifest instead of using the pinned versions.
5. **`matlabp` still points at a Vienna path.** Nothing in this image runs
   uncompiled MATLAB, so it is left at its default; only the compiled route
   (`-l`) is expected to work.
6. **`PART1_REF` and `PART2_REF` are still branch names.** Two builds a week
   apart can differ. `DEEPFIRE_REF` and `MRSIJL_REF` are pinned to commits;
   pin the other two as well for anything shipped. The verified build used
   `PART1_REF=afa7ac4 PART2_REF=0f4ffe3`.
