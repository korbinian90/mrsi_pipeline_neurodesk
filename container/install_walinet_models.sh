#!/usr/bin/env bash
#
# Bake the WALINET weights into the image at build time.
#
# The image is shipped to a collaborator as a tarball or a .sif, so the weights
# have to be inside it. Nothing is fetched at run time and nothing is mounted in.
#
#   model name   installed as              supplied by
#   ----------   ----------------------    ----------------------------------
#   7T           <models>/7T_Final         staged from a MRSIdeepFIRE checkout
#   3T           <models>/3T_Final         staged from a MRSIdeepFIRE checkout
#
# The names on the left are what walinet selects by (MODEL_LAYOUTS in
# walinet/package_config.py, and -Q's second argument in Part1); the paths in
# the middle are the directories that table maps them to. Both weigh about 1 GB
# and are gitignored in MRSIdeepFIRE, so build.sh copies them into the staging
# directory before the build.
#
# A model directory needs all three of model_best.pt, run_summary.txt and
# configs/. configs/ is easy to mistake for optional: besides the normalization
# lookup it holds the trained FID lengths, and inference without it runs but
# stops checking whether an acquisition length is supported at all.
#
# Usage: install_walinet_models.sh <staging dir> <models dir> [required]
#
# "required" is "all" (the default), "none", or a comma separated list of model
# names, and says which models the build insists on.

set -euo pipefail

STAGING_DIR=${1:?staging directory required}
MODELS_DIR=${2:?models directory required}
REQUIRED_SPEC=${3:-all}

ALL_MODELS="7T 3T"

model_directory() {
    case "$1" in
        7T) printf '%s' '7T_Final' ;;
        3T) printf '%s' '3T_Final' ;;
        *) echo "unknown WALINET model '$1'" >&2; return 1 ;;
    esac
}

# A staged directory that does not exist is not an error: a checkout without the
# weights still has to build, it just cannot require them.
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

missing_entries() {
    local dir=$1
    local missing=()
    [ -f "${dir}/model_best.pt" ]   || missing+=("model_best.pt")
    [ -f "${dir}/run_summary.txt" ] || missing+=("run_summary.txt")
    [ -d "${dir}/configs" ]         || missing+=("configs/")
    [ ${#missing[@]} -eq 0 ] || printf '%s\n' "${missing[@]}"
}

model_is_required() {
    local model=$1 required
    for required in ${REQUIRED_MODELS}; do
        [ "$required" = "$model" ] && return 0
    done
    return 1
}

case "$REQUIRED_SPEC" in
    all)  REQUIRED_MODELS="$ALL_MODELS" ;;
    none) REQUIRED_MODELS="" ;;
    *)    REQUIRED_MODELS="${REQUIRED_SPEC//,/ }" ;;
esac

for model in ${REQUIRED_MODELS}; do
    model_directory "$model" >/dev/null
done

for model in ${ALL_MODELS}; do
    install_staged_model "$model"
done

# Apptainer runs as the calling user, so nothing may depend on being root.
chmod -R a+rwX "${MODELS_DIR}"

failed=0
for model in ${ALL_MODELS}; do
    dir="${MODELS_DIR}/$(model_directory "$model")"

    if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
        mapfile -t missing < <(missing_entries "$dir")
        if [ ${#missing[@]} -gt 0 ]; then
            echo "ERROR: WALINET model '${model}' is incomplete in ${dir}" >&2
            printf '         missing: %s\n' "${missing[@]}" >&2
            failed=1
        else
            echo "WALINET ${model}: complete in ${dir}"
        fi
    elif model_is_required "$model"; then
        echo "ERROR: WALINET model '${model}' is required but not installed" >&2
        echo "       Stage it in container/walinet_models/${model}/ or let build.sh" >&2
        echo "       copy it from a MRSIdeepFIRE checkout (WALINET_MODELS_SRC)." >&2
        echo "       To build without it: REQUIRE_WALINET_MODELS=none" >&2
        failed=1
    else
        echo "WALINET ${model}: not installed, and not required by REQUIRE_WALINET_MODELS=${REQUIRED_SPEC}"
    fi
done

[ "$failed" -eq 0 ] || exit 1
