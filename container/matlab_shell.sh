#!/usr/bin/env bash
# Open a shell in the MATLAB development image, with the licence mounted and the
# MAC address pinned.
#
# The MAC matters. A MATLAB standalone licence is locked to a host ID, which on
# Linux is a MAC address, and Docker hands out a random one per container. Pin
# it and the same licence file keeps working across restarts.
#
#   ./container/matlab_shell.sh                 interactive shell
#   ./container/matlab_shell.sh matlab -batch … run one command and exit
#   ./container/matlab_shell.sh --print-ids      show the values the licence needs
#
# Environment:
#   IMAGE      image to run          (default mrsi-pipeline:matlab-dev)
#   MAC        pinned MAC address    (default 02:42:ac:11:00:99)
#   MATLAB_USER  login MATLAB runs as, must match the licence (default root)
#   DATA       host directory mounted at /data
#   OUT        host directory mounted at /out
set -euo pipefail

IMAGE=${IMAGE:-mrsi-pipeline:matlab-dev}
MAC=${MAC:-02:42:ac:11:00:99}
MATLAB_USER=${MATLAB_USER:-root}
REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
LICENSE="${REPO_ROOT}/container/matlab_local/license.lic"

# The host ID MathWorks wants is the MAC without separators.
HOSTID=$(printf '%s' "$MAC" | tr -d ':-' | tr 'A-Z' 'a-z')

if [ "${1:-}" = "--print-ids" ]; then
    cat <<EOF
Values to enter in the MathWorks License Center, under
"Activate to Retrieve License File":

  Operating system : Linux (64 bit)
  Host ID          : ${HOSTID}
  User name        : ${MATLAB_USER}
  Release          : see MATLAB_RELEASE in container/Dockerfile.matlab-dev

Save the downloaded file as:
  ${LICENSE}

The host ID is chosen here rather than discovered: this script pins it with
docker run --mac-address, so the container presents the same address every run.
EOF
    exit 0
fi

if [ ! -f "$LICENSE" ]; then
    echo "No licence at ${LICENSE}" >&2
    echo "Run './container/matlab_shell.sh --print-ids' for the values to request one," >&2
    echo "and see container/matlab_local/README.md for the steps." >&2
    exit 1
fi

args=(--rm --mac-address "$MAC" -v "${LICENSE}:/opt/matlab/licenses/license.lic:ro")

[ -n "${DATA:-}" ] && args+=(-v "${DATA}:/data")
[ -n "${OUT:-}" ] && args+=(-v "${OUT}:/out")
[ -t 0 ] && args+=(-it)

if [ "$#" -eq 0 ]; then
    exec docker run "${args[@]}" --entrypoint bash "${IMAGE}"
fi
exec docker run "${args[@]}" --entrypoint bash "${IMAGE}" -lc 'exec "$@"' _ "$@"
