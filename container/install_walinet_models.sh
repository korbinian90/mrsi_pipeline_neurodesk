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
# Usage: install_walinet_models.sh <staging dir> <models dir>

set -euo pipefail

STAGING_DIR=${1:?staging directory required}
MODELS_DIR=${2:?models directory required}

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

for model in ${ALL_MODELS}; do
    [ "$model" = "legacy_7T" ] || install_staged_model "$model"
done

# Apptainer runs as the calling user, so nothing may depend on being root.
chmod -R a+rwX "${MODELS_DIR}"
