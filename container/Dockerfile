# syntax=docker/dockerfile:1.7
#
# MRSI processing container, local build for one external collaborator and the
# Vienna developers. It is NOT published to Neurodesk and NOT built by public
# CI, so it may clone private repositories directly and never has to publish
# code or model weights.
#
# It depends on four upstream repositories at pinned refs instead of vendoring a
# merged copy: bump one ARG to pick up upstream work.
#
#   PART1_REF    -> Part1_Reco_LCModel_MUSICAL_Streamlined_Git    -> /opt/Part1
#   PART2_REF    -> Part2_Registration_Evaluation_Streamlined_Git -> /opt/Part2
#   DEEPFIRE_REF -> MRSIdeepFIRE                                  -> /opt/deepmrsi
#   MRSIJL_REF   -> MRSI.jl                                       -> /opt/MRSI.jl
#
# Build (BuildKit required, SSH agent forwarded for the private clones):
#
#   DOCKER_BUILDKIT=1 docker build --ssh default \
#       -f container/Dockerfile -t mrsi-pipeline:local .
#
# No credentials are baked into the image: the agent socket exists only for the
# duration of the RUN that mounts it, and only known_hosts is written to disk.
#
# Derived from the Neurodesk recipe recipes/mrsiproc/build.yaml (v0.2.0).
# Every deviation from that recipe is commented below with the reason.

FROM vnmd/fsl_6.0.7.1

LABEL org.opencontainers.image.title="MRSI processing pipeline (local build)"
LABEL org.opencontainers.image.description="Part1/Part2 MRSI processing with LCModel, MINC, FSL, MATLAB Runtime, Julia (MRSI.jl) and deepmrsi. Not published."

ARG DEBIAN_FRONTEND=noninteractive
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Versions of the third party components. These change far less often than the
# four repository refs, so they live in their own cache layers near the top.
ARG DCM2NIIX_REF=003f0d19f1e57b0129c9dcf3e653f51ca3559028
ARG MINC_VERSION=1.9.15
ARG LCMODEL_VERSION=6.3
ARG MATLAB_VERSION=2023a
ARG MATLAB_UPDATE_VERSION=8
ARG MRITOOLS_VERSION=4.5.3
ARG JULIA_VERSION=1.12.6

# CPU-only PyTorch by default (~190 MB against ~2.5 GB for the CUDA wheel and
# its nvidia-* closure). No CUDA runtime is installed. See the fitting notes at
# the bottom of this file for what that means on a GPU host.
ARG TORCH_INDEX_URL=https://download.pytorch.org/whl/cpu

# ---------------------------------------------------------------------------
# Base packages
#
# Carried over from the recipe. openssh-client is added for the private clones.
# Dropped against the recipe:
#   unrar, gv, vim, nano, openjdk-8-jre, dbus-x11 - never invoked by Part1,
#     Part2 or LCModel in batch mode; they only served the LCModel GUI and the
#     FreeSurfer desktop, neither of which this image runs.
#   csh/tcsh/xorg/xorg-dev/xserver-xorg-video-intel/x11-apps/xterm - installed
#     by the recipe purely as FreeSurfer prerequisites, and FreeSurfer is gone.
# ---------------------------------------------------------------------------
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
        bc \
        build-essential \
        ca-certificates \
        curl \
        datalad \
        gcc \
        git \
        gzip \
        libfftw3-3 \
        libxml2 \
        openssh-client \
        parallel \
        python3 \
        python3-pip \
        python3-venv \
        software-properties-common \
        tar \
        unzip \
        wget \
    && rm -rf /var/lib/apt/lists/*

# numpy 1.26.4 and the torch 2.3.1 wheels need Python >= 3.9. Fail here with a
# readable message instead of deep inside pip resolution.
RUN python3 -c 'import sys; assert sys.version_info >= (3, 9), f"python3 is {sys.version}, need >= 3.9"'

# ---------------------------------------------------------------------------
# dcm2niix
#
# KEPT. create_mask.sh converts the anatomical DICOM series, and dcm2mnc cannot
# read modern XA60 DICOMs, so the conversion path goes through dcm2niix and
# nii2mnc. Do not drop it.
# ---------------------------------------------------------------------------
ENV PATH="/opt/dcm2niix/bin:$PATH"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends cmake g++ make pigz zlib1g-dev \
    && rm -rf /var/lib/apt/lists/* \
    && git clone https://github.com/rordenlab/dcm2niix /tmp/dcm2niix \
    && git -C /tmp/dcm2niix fetch --tags \
    && git -C /tmp/dcm2niix checkout --detach "${DCM2NIIX_REF}" \
    && cmake -S /tmp/dcm2niix -B /tmp/dcm2niix/build -DCMAKE_INSTALL_PREFIX:PATH=/opt/dcm2niix \
    && cmake --build /tmp/dcm2niix/build --target install \
    && rm -rf /tmp/dcm2niix

# ---------------------------------------------------------------------------
# MINC toolkit 1.9.15 plus the ICBM152 models
#
# KEPT. Part1 and Part2 speak MINC throughout (rawtominc, mincresample,
# mincmath, minctoraw, mnc2nii, bestlinreg_s2, nlfit_s). The ICBM152 09a/09c
# models are what MNI_ATLAS_DIR points at.
# libjpeg62 is replaced by the turbo build, as in the recipe: the MINC binaries
# link against libjpeg62 and the stock Ubuntu package no longer provides it.
# The recipe's volgenmodel-nipype clone is dropped: it is an extra of the
# Neurodocker MINC template and neither Part1 nor Part2 calls it.
# ---------------------------------------------------------------------------
ENV MINC_TOOLKIT="/opt/minc-${MINC_VERSION}" \
    MINC_TOOLKIT_VERSION="/opt/minc-${MINC_VERSION}" \
    PATH="/opt/minc-${MINC_VERSION}/bin:/opt/minc-${MINC_VERSION}/pipeline:$PATH" \
    PERL5LIB="/opt/minc-${MINC_VERSION}/perl:/opt/minc-${MINC_VERSION}/pipeline:${PERL5LIB}" \
    LD_LIBRARY_PATH="/opt/minc-${MINC_VERSION}/lib:/opt/minc-${MINC_VERSION}/lib/InsightToolkit:${LD_LIBRARY_PATH}" \
    MNI_DATAPATH="/opt/minc-${MINC_VERSION}/share" \
    MINC_FORCE_V2="1" \
    MINC_COMPRESS="4" \
    VOLUME_CACHE_THRESHOLD="-1"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends \
        binutils ed gdebi-core imagemagick libc6 libgl1-mesa-dev libgl1-mesa-glx \
        libglu1-mesa libgomp1 libice6 libjpeg62 libsm6 libstdc++6 libx11-6 \
        libxext6 libxi6 libxmu6 octave perl \
    && rm -rf /var/lib/apt/lists/* \
    && cd / \
    && curl -fL https://packages.bic.mni.mcgill.ca/minc-toolkit/Debian/minc-toolkit-${MINC_VERSION}-20170529-Ubuntu_16.04-x86_64.deb -o minc.deb \
    && ar p minc.deb data.tar.gz | tar zx \
    && rm minc.deb \
    && ln -s /opt/minc/${MINC_VERSION} /opt/minc-${MINC_VERSION} \
    && curl -fL http://packages.bic.mni.mcgill.ca/tgz/beast-library-1.1.tar.gz | tar -xz -C /opt/minc-${MINC_VERSION}/share \
    && curl -fL -o /tmp/mni_90a.zip http://www.bic.mni.mcgill.ca/~vfonov/icbm/2009/mni_icbm152_nlin_sym_09a_minc2.zip \
    && unzip -q /tmp/mni_90a.zip -d /opt/minc-${MINC_VERSION}/share/icbm152_model_09a \
    && curl -fL -o /tmp/mni_90c.zip http://www.bic.mni.mcgill.ca/~vfonov/icbm/2009/mni_icbm152_nlin_sym_09c_minc2.zip \
    && unzip -q /tmp/mni_90c.zip -d /opt/minc-${MINC_VERSION}/share/icbm152_model_09c \
    && rm -rf /tmp/mni* \
    && apt-get update -qq \
    && apt-get remove -y libjpeg62 \
    && curl -fL -o /tmp/libjpeg62-turbo.deb http://ftp.br.debian.org/debian/pool/main/libj/libjpeg-turbo/libjpeg62-turbo_2.0.6-4_amd64.deb \
    && dpkg -i /tmp/libjpeg62-turbo.deb \
    && rm -f /tmp/libjpeg62-turbo.deb \
    && rm -rf /var/lib/apt/lists/*

# ---------------------------------------------------------------------------
# LCModel 6.3 core
#
# KEPT: the lcmodel binary is what RunLCModel.sh executes.
# DROPPED: the five basis set zips (3t, 1.5t, 7t, 9.4t and the ISMRM fitting
# challenge set). Nothing in Part1 or Part2 references .lcmodel/basis-sets; the
# basis file always arrives through the -b argument of Part1_ProcessMRSI.sh
# (the repository ships fid_1.300000ms.basis for that).
# The GUI profile defaults (controlfiledefault, gui-defaults, setup_lcmodel.sh)
# from the Neurodesk recipe are also not carried over: they configure the
# interactive LCModel GUI, and this image only runs lcmodel headless against a
# control file written by the pipeline.
# ---------------------------------------------------------------------------
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends libnet-ifconfig-wrapper-perl libxft2 libxss1 \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /opt/lcmodel-${LCMODEL_VERSION} \
    && cd /opt/lcmodel-${LCMODEL_VERSION} \
    && curl -fL -o lcm-64.tar https://s-provencher.com/pub/LCModel/programs/lcm-64.tar \
    && tar xf lcm-64.tar \
    && rm -f lcm-64.tar \
    && gunzip -c lcm-core.tar.gz | tar xf - \
    && rm -f lcm-core.tar.gz \
    && chmod a+rwx /opt/lcmodel-${LCMODEL_VERSION} -R
ENV PATH="${PATH}:/opt/lcmodel-${LCMODEL_VERSION}/.lcmodel/bin:/opt/lcmodel-${LCMODEL_VERSION}/.lcmodel"
# Only a default: Part1/InstallProgramPaths.sh resets LCM_Path when it is sourced.
ENV LCM_Path="/opt/lcmodel-${LCMODEL_VERSION}/.lcmodel/bin/lcmodel"

# ---------------------------------------------------------------------------
# MATLAB Runtime R2023a
#
# KEPT, and mandatory: every compiled binary in Part1/Matlab_Compiled and
# Part2/Matlab_Compiled was built against R2023a - both Matlab_Compiled
# readme.txt files say "Verify that MATLAB Runtime(R2023a) is installed" - and
# both InstallProgramPaths.sh scripts put /opt/MATLAB_Runtime_R2023a/R2023a/...
# on LD_LIBRARY_PATH. About 4.7 GB of installer download, the single largest
# component of the image and not removable without recompiling the MATLAB code.
#
# From R2023a on, the runtime installs into a release-named subdirectory
# (R2023a) rather than the older version-numbered one (v911 for R2021b), so
# MATLAB_RUNTIME_ROOT derives the whole path from MATLAB_VERSION and nothing
# below repeats a release string. The install step asserts that the derived
# directory exists, so bumping MATLAB_VERSION to a release with a different
# layout fails here instead of leaving LD_LIBRARY_PATH pointing at nothing.
# ---------------------------------------------------------------------------
ENV MATLAB_RUNTIME_ROOT="/opt/MATLAB_Runtime_R${MATLAB_VERSION}/R${MATLAB_VERSION}"
RUN apt-get update -qq \
    && apt-get install -y -q --no-install-recommends libncurses5 libxext6 libxmu6 libxpm-dev libxt6 \
    && rm -rf /var/lib/apt/lists/* \
    && cd /opt \
    && curl -fL -O "https://ssd.mathworks.com/supportfiles/downloads/R${MATLAB_VERSION}/Release/${MATLAB_UPDATE_VERSION}/deployment_files/installer/complete/glnxa64/MATLAB_Runtime_R${MATLAB_VERSION}_Update_${MATLAB_UPDATE_VERSION}_glnxa64.zip" \
    && unzip -q "MATLAB_Runtime_R${MATLAB_VERSION}_Update_${MATLAB_UPDATE_VERSION}_glnxa64.zip" -d mcrtmp \
    && mcrtmp/install -mode silent -destinationFolder "/opt/MATLAB_Runtime_R${MATLAB_VERSION}" -agreeToLicense yes \
    && rm -rf mcrtmp "MATLAB_Runtime_R${MATLAB_VERSION}_Update_${MATLAB_UPDATE_VERSION}_glnxa64.zip" \
    && test -d "${MATLAB_RUNTIME_ROOT}/runtime/glnxa64"
ENV LD_LIBRARY_PATH="${LD_LIBRARY_PATH}:${MATLAB_RUNTIME_ROOT}/runtime/glnxa64:${MATLAB_RUNTIME_ROOT}/bin/glnxa64:${MATLAB_RUNTIME_ROOT}/sys/os/glnxa64:${MATLAB_RUNTIME_ROOT}/sys/opengl/lib/glnxa64:${MATLAB_RUNTIME_ROOT}/extern/bin/glnxa64"

# ---------------------------------------------------------------------------
# NOT INSTALLED: FreeSurfer 7.4.1 (~9.5 GB)
#
# The recipe installed it for Part2/Bash_Functions/Segmentation/synthseg.sh,
# which calls mri_synthseg. That branch is being deleted from Part2, and none of
# the 11 unique compiled MATLAB binaries in this repository (4 in
# Part1/Matlab_Compiled, 4 in Part2/Matlab_Compiled, 3 in matlab_compiled)
# contains a single FreeSurfer string. Its X11/csh apt prerequisites went with
# it (see the base layer).
#
# NOT INSTALLED: HD-BET and its CUDA torch / nnU-Net closure (~6.3 GB)
#
# Zero matches repo-wide. Brain extraction runs through FSL bet, which comes
# from the base image, and the deepmrsi masking path calls plain "bet" too.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# mritools (makehomogeneous)
#
# ADDED against the recipe: deep_crt_mrsi/bet_mask.py shells out to the
# absolute path /opt/mritools/bin/makehomogeneous before running bet, so the
# deepmrsi masking step needs this exact location.
# ---------------------------------------------------------------------------
RUN curl -fL -o /tmp/mritools.tar.gz "https://github.com/korbinian90/CompileMRI.jl/releases/download/v${MRITOOLS_VERSION}/mritools_ubuntu-22.04_${MRITOOLS_VERSION}.tar.gz" \
    && tar -xzf /tmp/mritools.tar.gz -C /opt \
    && mv /opt/mritools_ubuntu-22.04_${MRITOOLS_VERSION} /opt/mritools \
    && rm -f /tmp/mritools.tar.gz

# ---------------------------------------------------------------------------
# Julia
#
# JULIA_VERSION must match julia_version in the MRSIdeepFIRE Manifest.toml
# (offline_pipeline/Manifest.toml), otherwise Julia re-resolves that manifest
# instead of using the pinned versions.
# ---------------------------------------------------------------------------
ENV JULIA_DEPOT_PATH=/opt/julia_depot
RUN curl -fL "https://julialang-s3.julialang.org/bin/linux/x64/${JULIA_VERSION%.*}/julia-${JULIA_VERSION}-linux-x86_64.tar.gz" | tar xz -C /opt \
    && ln -s /opt/julia-${JULIA_VERSION}/bin/julia /usr/local/bin/julia

# ---------------------------------------------------------------------------
# Python environment for deepmrsi
#
# A dedicated venv keeps the pipeline's Python away from the base image's FSL
# Python. torch comes from TORCH_INDEX_URL first so that the pinned
# torch==2.3.1 in the deepmrsi requirements is already satisfied and pip does
# not pull the default CUDA wheel from PyPI.
# linear_operator and gpytorch are the forD_gpu_fit dependencies.
# ---------------------------------------------------------------------------
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip setuptools==81.0.0 wheel \
    && pip install --no-cache-dir torch==2.3.1 torchvision==0.18.1 --index-url "${TORCH_INDEX_URL}" \
    && pip install --no-cache-dir linear_operator gpytorch

# ---------------------------------------------------------------------------
# Private repositories, pinned
#
# --mount=type=ssh forwards the caller's agent for the duration of the RUN only.
# Nothing but known_hosts is written into the image.
# The clones are ordered so that bumping PART1_REF or PART2_REF, which happens
# most often, invalidates the fewest layers.
#
# Each ref may be a branch, a tag or a raw SHA. After a clone a branch exists
# only as a remote-tracking ref, and "git checkout --detach <branch>" then dies
# with "'--detach' cannot be used with '-b/-B/--orphan'" because git tries to
# create a local tracking branch. So resolve origin/<ref> first and fall back
# to <ref> for tags and SHAs, which have no origin/ prefix. A ref that is none
# of the three still fails the build, as it should.
# ---------------------------------------------------------------------------
ARG DEEPFIRE_REF=main
ARG MRSIJL_REF=main
ARG PART1_REF=julia-reco
ARG PART2_REF=master

RUN mkdir -p -m 0700 /root/.ssh && ssh-keyscan -t rsa,ecdsa,ed25519 github.com >> /root/.ssh/known_hosts

RUN --mount=type=ssh \
    git clone git@github.com:korbinian90/MRSIdeepFIRE.git /opt/deepmrsi \
    && { git -C /opt/deepmrsi checkout --detach "origin/${DEEPFIRE_REF}" 2>/dev/null \
         || git -C /opt/deepmrsi checkout --detach "${DEEPFIRE_REF}"; }

RUN --mount=type=ssh \
    git clone git@github.com:korbinian90/MRSI.jl.git /opt/MRSI.jl \
    && { git -C /opt/MRSI.jl checkout --detach "origin/${MRSIJL_REF}" 2>/dev/null \
         || git -C /opt/MRSI.jl checkout --detach "${MRSIJL_REF}"; }

# deepmrsi Python packages, installed editable from the pinned checkout so the
# image and the checkout can never disagree about which code ran.
#
# deepMRSI/requirements.txt is checked in as UTF-16LE with a BOM. pip's legacy
# auto-decoding of that is not something to rely on, so transcode to UTF-8
# first rather than let the build depend on the pip version in the image.
RUN iconv -f UTF-16 -t UTF-8 /opt/deepmrsi/deepMRSI/requirements.txt > /tmp/deepmrsi-requirements.txt \
    && pip install --no-cache-dir -r /tmp/deepmrsi-requirements.txt \
    && rm -f /tmp/deepmrsi-requirements.txt \
    && pip install --no-cache-dir -e /opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/deep_crt_mrsi \
    && pip install --no-cache-dir -e /opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/mrs_utils \
    && pip install --no-cache-dir -e /opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/forD_gpu_fit \
    && pip install --no-cache-dir -e /opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/forD \
    && pip install --no-cache-dir -e /opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/walinet \
    && python -c 'import torch; print("torch", torch.__version__, "cuda build", torch.version.cuda)'

# WALINET model directory. The package resolves its weights relative to
# walinet/models and has no setting for that location, so the directory is
# moved to a writable path outside the package and symlinked back. That keeps
# the weights readable and writable for an Apptainer run, which is not root.
#
# Build-time only, deliberately not an ENV: nothing reads this variable, the
# relocation works purely through the symlink below, so exporting it would
# advertise a runtime knob that has no effect.
ARG WALINET_MODEL_DIR=/opt/walinet_models
RUN WALINET_PKG=/opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/walinet/walinet \
    && mv "${WALINET_PKG}/models" "${WALINET_MODEL_DIR}" \
    && ln -s "${WALINET_MODEL_DIR}" "${WALINET_PKG}/models" \
    && chmod -R a+rwX "${WALINET_MODEL_DIR}"

# Bake the WALINET weights in. The image is handed over as a tarball or a .sif,
# so nothing may be fetched or mounted at run time.
#
# legacy_7T arrives with the checkout above (it is tracked in MRSIdeepFIRE) and
# is selectable with no user action. final_7T and final_3T are not in any git
# repository and are staged by hand into container/walinet_models/<name>/
# before the build; see that directory's README.
#
# The staging tree is bind mounted from the build context instead of COPYed in.
# A COPY layer would keep a second copy of the ~1 GB final_7T checkpoint in the
# shipped image forever, because moving it into place afterwards cannot remove
# it from the layer underneath. BuildKit is already required for the
# --mount=type=ssh clones above, so this adds no new constraint. Nothing is
# staged in a fresh clone, and the step is a no-op then.
#
# Whatever ends up installed is validated against the layout walinet expects,
# so a missing or half-copied model stops the build with the names of the files
# it wants, instead of shipping an image that dies mid-reconstruction.
# REQUIRE_WALINET_MODELS says which models the build insists on: the default
# only demands legacy_7T, so a build without the separately shipped weights
# still works. The image for the collaborator is built with
#   --build-arg REQUIRE_WALINET_MODELS=all
ARG REQUIRE_WALINET_MODELS=legacy_7T
RUN --mount=type=bind,source=walinet_models,target=/tmp/walinet_staging \
    --mount=type=bind,source=install_walinet_models.sh,target=/tmp/install_walinet_models.sh \
    bash /tmp/install_walinet_models.sh /tmp/walinet_staging "${WALINET_MODEL_DIR}" \
         "${REQUIRE_WALINET_MODELS}"

# Julia packages: MRSI.jl developed into the shared depot so that both the
# Part1 reconstruction (which activates JULIA_MRSI_PKG) and a bare `julia` see
# it, plus the deepmrsi offline pipeline project. Note that the offline
# pipeline resolves MRSI through its own subtree copy under
# offline_pipeline/MRSI, so it follows DEEPFIRE_REF and not MRSIJL_REF.
RUN julia --startup-file=no -e 'using Pkg; Pkg.develop(path="/opt/MRSI.jl"); Pkg.precompile()' \
    && julia --startup-file=no --project=/opt/deepmrsi/offline_pipeline -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()' \
    && chmod -R a+rwX /opt/julia_depot

RUN --mount=type=ssh \
    git clone git@github.com:phipzl/Part1_Reco_LCModel_MUSICAL_Streamlined_Git.git /opt/Part1 \
    && { git -C /opt/Part1 checkout --detach "origin/${PART1_REF}" 2>/dev/null \
         || git -C /opt/Part1 checkout --detach "${PART1_REF}"; }

RUN --mount=type=ssh \
    git clone git@github.com:phipzl/Part2_Registration_Evaluation_Streamlined_Git.git /opt/Part2 \
    && { git -C /opt/Part2 checkout --detach "origin/${PART2_REF}" 2>/dev/null \
         || git -C /opt/Part2 checkout --detach "${PART2_REF}"; }

# ---------------------------------------------------------------------------
# Pipeline environment
#
# JULIA_MRSI_PKG is Pkg.activate'd by Part1/run_julia_reco.jl.
# JULIA_DEEPMRSI_PKG is the project with the pinned deepmrsi Julia manifest.
# MNI_ATLAS_DIR holds mni_icbm152_nlin_sym_09a, the atlas Part2's
# coregistration.sh resamples to.
# MatlabFunctionsFolder is only a default: both InstallProgramPaths.sh scripts
# reset it to their own checkout when they are sourced.
# ---------------------------------------------------------------------------
ENV JULIA_MRSI_PKG=/opt/MRSI.jl \
    JULIA_DEEPMRSI_PKG=/opt/deepmrsi/offline_pipeline \
    MNI_ATLAS_DIR=/opt/minc-${MINC_VERSION}/share/icbm152_model_09a \
    MatlabFunctionsFolder=/opt/Part1/MatlabFunctions \
    MatlabCompiledFunctions=Matlab_Compiled
ENV PATH="/opt/Part1:/opt/Part2:${PATH}"

# ---------------------------------------------------------------------------
# Fitting backend and GPU behaviour
#
# The fitter is chosen in
# /opt/deepmrsi/python-ismrmrd-server/DEEP_CRT_MRSI/install/deep_crt_mrsi/package_config.json
# ("fitting": auto | dlfit | gpufit | off). The choice is a setting and
# deliberately not a CUDA probe, so the same protocol yields the same algorithm
# everywhere; only the device changes. With gpufit and no visible CUDA device,
# forD_gpu_fit runs the identical algorithm on the CPU, roughly an order of
# magnitude slower.
#
# This image installs no CUDA runtime. To let a GPU host accelerate the same
# code path, rebuild with
#   --build-arg TORCH_INDEX_URL=https://download.pytorch.org/whl/cu118
# and run with --gpus all (or an Apptainer --nv run). The CPU-only wheel that
# is built by default reports torch.cuda.is_available() == False even when
# libcuda is present.
# ---------------------------------------------------------------------------

WORKDIR /data
CMD ["/bin/bash"]
