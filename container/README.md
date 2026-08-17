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

The defaults are branch names (`julia-reco`, `master`, `main`, `main`), which
are convenient for development but are not reproducible. For anything you hand
to the collaborator, pass explicit commit SHAs and note them down. After a
build, the image can tell you what it actually contains:

```bash
docker run --rm mrsi-pipeline:local bash -lc \
  'for r in /opt/Part1 /opt/Part2 /opt/deepmrsi /opt/MRSI.jl; do
       echo -n "$r "; git -C $r rev-parse HEAD; done'
```

## Exporting for the collaborator

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
  the 14 compiled MATLAB binaries.
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
`JULIA_DEEPMRSI_PKG=/opt/deepmrsi/offline_pipeline`,
`WALINET_MODEL_DIR=/opt/walinet_models`, `MNI_ATLAS_DIR`,
`MatlabFunctionsFolder`, and `/opt/Part1` plus `/opt/Part2` on `PATH`.

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

## WALINET model

`walinet` resolves its weights as
`<walinet package>/models/<model_relative_path>`, and the image relocates that
directory to `WALINET_MODEL_DIR=/opt/walinet_models` (world writable, symlinked
back into the package) so weights can be added without a rebuild.

The default `model_relative_path` is `7T_Final`, an experiment directory of
about 1 GB that is **gitignored upstream and therefore not in the clone**. It
has to be supplied at run time:

```bash
docker run --rm -v /path/to/7T_Final:/opt/walinet_models/7T_Final:ro ...
```

The small `model_best.pt` that upstream does track sits at the root of the
models directory. It is a different, older checkpoint and is not a drop-in for
`7T_Final`, whose loader also reads the experiment's `configs/`. If no WALINET
weights are available, set `"apply_walinet": false` in the `deep_crt_mrsi`
`package_config.json` and the run skips water/lipid removal.

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

## Not yet verified

Written honestly, because none of the following has been proven by a run:

1. **The image has been authored, not built.** No `docker build` was executed,
   so download URLs, apt names on this particular base image, and the Julia and
   pip resolution steps are unproven. Expect the first build to need fixes.
2. **The upstream `InstallProgramPaths.sh` files carry Vienna site paths.**
   Both `Part1_ProcessMRSI.sh` and `Part2_EvaluateMRSI.sh` source their own
   repository copy, which overrides the container environment with
   `matlabp=/bilbo/usr/local/matlab2022a/bin/matlab`,
   `LCM_Path=/usr/local/lcmodel/bin/lcmodel`, `RunLCModelOn="lcm"` (an SSH hop
   to another host), a `/ceph/...` `tmp_folder`, and
   `. /opt/minc/minc-toolkit-config.sh` (the toolkit lands in
   `/opt/minc/1.9.15/` here). The merged `mrsi_pipeline_neurodesk` repository
   has a container-adapted version of that file; the pinned upstream repos do
   not. Until upstream grows a container profile, mount a corrected copy over
   `/opt/Part1/InstallProgramPaths.sh` and `/opt/Part2/InstallProgramPaths.sh`.
3. **Part2 upstream ships no `Matlab_Compiled` directory** on any branch that
   was checked. The compiled Part2 binaries currently exist only in the merged
   `mrsi_pipeline_neurodesk` repository, so `-l` (compiled MATLAB) will not
   find them in this image unless they are mounted in.
4. **`julia_write_lcm_files`**, which `run_matlab.sh` calls after a Julia
   reconstruction, is likewise only in the merged repository's
   `matlab_compiled/`, not in Part1's `Matlab_Compiled`.
5. **`MNI_ATLAS_DIR` is not consumed by any script yet.**
   `Part2/Bash_Functions/Coreg/coregistration.sh` still hardcodes
   `/net/mri.meduniwien.ac.at/.../lab/$atlas_type`. The variable is set here so
   that upstream can start reading it; the MNI152 09a atlas is present under
   it, while the MNI305 `average305_t1_tal_lin.mnc` alternative was not
   confirmed to ship with minc-toolkit.
6. **The dcm2niix rationale comes from the newer upstream conversion path.**
   The Part1 checkout inspected while writing this still calls `dcm2mnc` in
   `create_mask.sh`, so keeping dcm2niix is what makes the newer path work, not
   something the current pinned default ref exercises.
7. **`JULIA_VERSION` (1.12.6) was read from the MRSIdeepFIRE
   `offline_pipeline/Manifest.toml`.** If `DEEPFIRE_REF` moves to a manifest
   with another `julia_version`, bump the arg too, or Julia re-resolves the
   manifest instead of using the pinned versions.
8. **The base image's Python version is not pinned by us.** The build asserts
   `python3 >= 3.9` early, since numpy 1.26.4 and the torch 2.3.1 wheels need
   it. If `vnmd/fsl_6.0.7.1` ships something older, that assertion is where the
   build stops.
9. **The default refs are branches, not commits.** Two builds a week apart can
   differ. Pass SHAs for anything shipped.
