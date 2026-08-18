#!/usr/bin/env bash
#
# Build the local MRSI processing container.
#
# The image is not published: it is built here and shipped to the collaborator
# as a docker save tarball or an Apptainer .sif. Two clones are private, so the
# build forwards your SSH agent with BuildKit's --ssh default. Nothing is
# written into the image except github.com's host keys.
#
# Usage:
#   ./build.sh [extra docker build args...]
#
# Everything is overridable through the environment:
#   IMAGE            image name:tag                  (default mrsi-pipeline:local)
#   PART1_REF        Part1 branch, tag or commit
#   PART2_REF        Part2 branch, tag or commit
#   DEEPFIRE_REF     MRSIdeepFIRE ref
#   MRSIJL_REF       MRSI.jl ref
#   TORCH_INDEX_URL  PyTorch wheel index
#   REQUIRE_WALINET_MODELS
#                    which baked-in WALINET models the build insists on:
#                    legacy_7T (default), all, or a comma separated list
#
# Only the variables you actually set are passed on as --build-arg, so the
# Dockerfile's ARG defaults stay the single source of truth for the rest. Do
# not repeat those defaults here: two lists drift.
#
# Examples:
#   ./build.sh
#   PART1_REF=3f2a1c9 ./build.sh
#   TORCH_INDEX_URL=https://download.pytorch.org/whl/cu118 ./build.sh
#   REQUIRE_WALINET_MODELS=all ./build.sh     # the shipping build
#   ./build.sh --progress=plain --no-cache

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

IMAGE="${IMAGE:-mrsi-pipeline:local}"

BUILD_ARGS=()
for var in PART1_REF PART2_REF DEEPFIRE_REF MRSIJL_REF TORCH_INDEX_URL REQUIRE_WALINET_MODELS; do
    if [[ -n "${!var:-}" ]]; then
        BUILD_ARGS+=(--build-arg "${var}=${!var}")
    fi
done

# Windows has no SSH_AUTH_SOCK: the OpenSSH agent is a named pipe, and Docker
# Desktop forwards it when the pipe is named explicitly. Detect that case
# rather than failing the guard below on an otherwise working setup.
SSH_FORWARD="default"
case "$(uname -s 2>/dev/null || echo unknown)" in
    MINGW*|MSYS*|CYGWIN*)
        SSH_FORWARD='default=\\.\pipe\openssh-ssh-agent'
        if ! sc query ssh-agent 2>/dev/null | grep -q RUNNING; then
            echo "ERROR: the Windows ssh-agent service is not running." >&2
            echo "       Start it with: Start-Service ssh-agent" >&2
            echo "       then load a key with: ssh-add" >&2
            exit 1
        fi
        ;;
    *)
        if [[ -z "${SSH_AUTH_SOCK:-}" ]]; then
            echo "ERROR: no SSH agent found (SSH_AUTH_SOCK is empty)." >&2
            echo "       'docker build --ssh default' needs a running agent that can" >&2
            echo "       read the private Part1, Part2 and MRSIdeepFIRE repositories." >&2
            echo "       Start one with: eval \"\$(ssh-agent -s)\" && ssh-add" >&2
            exit 1
        fi
        ;;
esac

echo "Building ${IMAGE}"
for var in PART1_REF PART2_REF DEEPFIRE_REF MRSIJL_REF TORCH_INDEX_URL REQUIRE_WALINET_MODELS; do
    printf '  %-15s = %s\n' "${var}" "${!var:-<Dockerfile default>}"
done

DOCKER_BUILDKIT=1 docker build \
    --ssh "${SSH_FORWARD}" \
    ${BUILD_ARGS[@]+"${BUILD_ARGS[@]}"} \
    -t "${IMAGE}" \
    -f "${SCRIPT_DIR}/Dockerfile" \
    "$@" \
    "${SCRIPT_DIR}/.."

echo
echo "Done. Record the refs that went in:"
echo "  docker run --rm ${IMAGE} bash -lc 'for r in /opt/Part1 /opt/Part2 /opt/deepmrsi /opt/MRSI.jl; do echo -n \"\$r \"; git -C \$r rev-parse HEAD; done'"
