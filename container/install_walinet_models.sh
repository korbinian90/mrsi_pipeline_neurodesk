#!/usr/bin/env bash
#
# Bake the WALINET weights into the image at build time.
#
# The image is shipped to a collaborator as a tarball or a .sif, so the weights
# have to be inside it. Nothing is fetched at run time and nothing has to be
# mounted in.
#
#   model name   installed as                  supplied by
#   ----------   ---------------------------   ----------------------------
#   legacy_7T    <models>/                     the pinned MRSIdeepFIRE
#                model_best.pt + config.json   checkout, tracked in its git
#   final_7T     <models>/7T_Final             staged by hand, about 1 GB
#   final_3T     <models>/3T_Final             staged by hand
#
# The names on the left are the ones walinet selects by (MODEL_LAYOUTS in
# walinet/package_config.py, and --walinet_model on deepmrsi.py); the paths in
# the middle are the directories that table maps them to. legacy_7T maps to the
# models root, which the checkout already fills, so it needs no staging at all.
#
# Whatever ends up installed is validated here, so a missing or half-copied
# model fails the build with the file names it needs instead of producing an
# image whose model selection dies in the middle of a reconstruction.
#
# Usage: install_walinet_models.sh <staging dir> <models dir> [required]
#
# "required" is "all", or a comma separated list of model names, and says which
# models the build insists on. It defaults to legacy_7T so a build without the
# separately shipped weights still succeeds; the image for the collaborator is
# built with "all".

set -euo pipefail

STAGING_DIR=${1:?staging directory required}
MODELS_DIR=${2:?models directory required}
REQUIRED_SPEC=${3:-legacy_7T}

ALL_MODELS="legacy_7T final_7T final_3T"

model_directory() {
    case "$1" in
        legacy_7T) printf '%s' '.' ;;
        final_7T)  printf '%s' '7T_Final' ;;
        final_3T)  printf '%s' '3T_Final' ;;
        *) echo "unknown WALINET model '$1'" >&2; return 1 ;;
    esac
}

# A staged directory that does not exist is not an error: a fresh clone stages
# nothing and still has to build.
install_staged_model() {
    local model=$1
    local src="${STAGING_DIR}/${model}"
    local dest="${MODELS_DIR}/$(model_directory "$model")"

    if [ ! -d "$src" ] || [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
        echo "WALINET ${model}: nothing staged in ${src}"
        return 0
    fi

    echo "WALINET ${model}: installing $(du -sh "$src" | cut -f1) into ${dest}"
    mkdir -p "$dest"
    cp -a "${src}/." "${dest}/"
}

# The entries that make a model directory complete, mirroring MODEL_LAYOUTS in
# walinet/package_config.py. The two layouts differ: the in-repo legacy model is
# a bare checkpoint next to its config.json, while a separately shipped model
# also carries run_summary.txt (the architecture) and configs/ (the trained FID
# lengths). Checking only the checkpoint would let a half-copied new-format
# directory load through the legacy path and silently drop the FID-length
# handling, which is what that table exists to prevent.
missing_entries() {
    local model=$1 dir=$2
    local missing=()

    if [ "$model" = "legacy_7T" ]; then
        if [ ! -f "${dir}/model_best.pt" ] && ! compgen -G "${dir}/*.pt" >/dev/null; then
            missing+=("model_best.pt (or another flat .pt checkpoint)")
        fi
        [ -f "${dir}/config.json" ] || missing+=("config.json")
    else
        [ -f "${dir}/model_best.pt" ]   || missing+=("model_best.pt")
        [ -f "${dir}/run_summary.txt" ] || missing+=("run_summary.txt")
        [ -d "${dir}/configs" ]         || missing+=("configs/")
    fi

    [ ${#missing[@]} -eq 0 ] || printf '%s\n' "${missing[@]}"
}

# legacy_7T lives in the models root, which always exists, so its presence is
# decided by its contents rather than by the directory.
model_is_present() {
    local model=$1 dir=$2

    if [ "$model" = "legacy_7T" ]; then
        [ -f "${dir}/config.json" ] || compgen -G "${dir}/*.pt" >/dev/null
    else
        [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]
    fi
}

model_is_required() {
    local model=$1 required
    for required in ${REQUIRED_MODELS}; do
        if [ "$required" = "$model" ]; then
            return 0
        fi
    done
    return 1
}

report_incomplete() {
    local model=$1 dir=$2
    shift 2

    echo "ERROR: WALINET model '${model}' is incomplete in ${dir}" >&2
    printf '         missing: %s\n' "$@" >&2

    if [ "$model" = "legacy_7T" ]; then
        echo "       legacy_7T is tracked in MRSIdeepFIRE and needs no staging, so the" >&2
        echo "       pinned DEEPFIRE_REF no longer ships walinet/models/. Pin a ref that" >&2
        echo "       does, or drop legacy_7T from REQUIRE_WALINET_MODELS." >&2
    else
        echo "       Copy the complete model directory to container/walinet_models/${model}/" >&2
        echo "       and rebuild. See container/walinet_models/README.md." >&2
    fi
}

if [ "$REQUIRED_SPEC" = "all" ]; then
    REQUIRED_MODELS="$ALL_MODELS"
else
    REQUIRED_MODELS="${REQUIRED_SPEC//,/ }"
fi

for model in ${REQUIRED_MODELS}; do
    model_directory "$model" >/dev/null
done

for model in ${ALL_MODELS}; do
    [ "$model" = "legacy_7T" ] || install_staged_model "$model"
done

# Apptainer runs as the calling user, so nothing may depend on being root.
chmod -R a+rwX "${MODELS_DIR}"

failed=0
for model in ${ALL_MODELS}; do
    dir="${MODELS_DIR}/$(model_directory "$model")"
    dir=${dir%/.}

    if model_is_present "$model" "$dir"; then
        mapfile -t missing < <(missing_entries "$model" "$dir")
        if [ ${#missing[@]} -gt 0 ]; then
            report_incomplete "$model" "$dir" "${missing[@]}"
            failed=1
        else
            echo "WALINET ${model}: complete in ${dir}"
        fi
    elif model_is_required "$model"; then
        mapfile -t missing < <(missing_entries "$model" "$dir")
        report_incomplete "$model" "$dir" "${missing[@]}"
        failed=1
    else
        echo "WALINET ${model}: not installed, and not required by REQUIRE_WALINET_MODELS=${REQUIRED_SPEC}"
    fi
done

[ "$failed" -eq 0 ] || exit 1
