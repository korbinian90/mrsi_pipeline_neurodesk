#! /usr/bin/env bash
# Remove images this build line has superseded, so a long series of release
# candidates does not fill the disk. Each image is tens of gigabytes.
#
# Usage:
#   ./prune_images.sh [image[:tag]]
#
# With no argument it prunes the repository named by IMAGE. The image passed in
# is always kept, as are the KEEP most recent others and anything listed in
# KEEP_TAGS. An image that any container still refers to is never removed.
#
# Environment:
#   IMAGE       image this build line produces (default mrsi-pipeline:local)
#   KEEP        superseded images to keep besides the current one (default 1)
#   KEEP_TAGS   space separated tags to keep regardless of age
#   CACHE_LIMIT build cache budget, e.g. 20GB; empty disables cache pruning
#   DRY_RUN     set to 1 to print what would go without removing it

set -euo pipefail

IMAGE="${1:-${IMAGE:-mrsi-pipeline:local}}"
KEEP="${KEEP:-1}"
KEEP_TAGS="${KEEP_TAGS:-matlab-dev}"
CACHE_LIMIT="${CACHE_LIMIT:-20GB}"
DRY_RUN="${DRY_RUN:-0}"

repo="${IMAGE%:*}"

run() {
    if [[ ${DRY_RUN} == 1 ]]; then
        echo "  would run: $*"
    else
        "$@" >/dev/null 2>&1 || return 1
    fi
}

# Newest first, so the head of the list is what we keep.
tags=()
while read -r tag; do
    [[ -z ${tag} ]] && continue
    created=$(docker image inspect -f '{{.Created}}' "${tag}" 2>/dev/null) || continue
    tags+=("${created}	${tag}")
done < <(docker images "${repo}" --format '{{.Repository}}:{{.Tag}}' | grep -v ':<none>$' || true)

if [[ ${#tags[@]} -eq 0 ]]; then
    echo "No ${repo} images to prune."
else
    ordered=()
    while read -r _ tag; do
        ordered+=("${tag}")
    done < <(printf '%s\n' "${tags[@]}" | sort -r)

    kept=0
    for tag in "${ordered[@]}"; do
        keep_this=0
        [[ ${tag} == "${IMAGE}" ]] && keep_this=1
        for protected in ${KEEP_TAGS}; do
            [[ ${tag} == "${protected}" || ${tag} == "${repo}:${protected}" ]] && keep_this=1
        done
        if [[ ${keep_this} -eq 0 && ${kept} -lt ${KEEP} ]]; then
            keep_this=1
            kept=$((kept + 1))
        fi

        if [[ ${keep_this} -eq 1 ]]; then
            echo "keep   ${tag}"
            continue
        fi

        users=$(docker ps -a --filter "ancestor=${tag}" --format '{{.Names}}' 2>/dev/null || true)
        if [[ -n ${users} ]]; then
            echo "keep   ${tag} (in use by ${users//$'\n'/, })"
            continue
        fi

        if run docker rmi "${tag}"; then
            echo "remove ${tag}"
        else
            echo "keep   ${tag} (could not be removed)"
        fi
    done
fi

# Layers left behind by a rebuild belong to nothing and are pure waste.
dangling=$(docker images -f dangling=true -q | wc -l | tr -d ' ')
if [[ ${dangling} != 0 ]]; then
    echo "remove ${dangling} dangling image(s)"
    run docker image prune -f || true
fi

if [[ -n ${CACHE_LIMIT} ]]; then
    if [[ ${DRY_RUN} == 1 ]]; then
        echo "  would cap the build cache at ${CACHE_LIMIT}"
    else
        docker builder prune -f --keep-storage "${CACHE_LIMIT}" >/dev/null 2>&1 ||
            docker builder prune -f --max-used-space "${CACHE_LIMIT}" >/dev/null 2>&1 || true
        echo "build cache capped at ${CACHE_LIMIT}"
    fi
fi
