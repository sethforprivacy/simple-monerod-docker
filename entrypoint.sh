#!/bin/sh
set -e

# Default to the built-in monero user's UID/GID; override for
# bind-mount/NAS setups where the data directory is owned elsewhere.
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# Require --non-interactive so monerod stays attached as PID 1 and logs to stdout
set -- "monerod" "--non-interactive" "$@"

# Configure NUMA interleaving only when the kernel actually supports it:
# numactl exits nonzero on non-NUMA systems, which would kill the container.
if command -v numactl >/dev/null 2>&1 && numactl --show >/dev/null 2>&1; then
    set -- numactl --interleave=all "$@"
fi

# When started as root (the image default), normalize data-dir ownership for
# the requested UID/GID, then drop all privileges for the daemon itself.
if [ "$(id -u)" = "0" ]; then
    DATA_DIR="/home/monero/.bitmonero"
    CUR_UID="$(stat -c %u "$DATA_DIR" 2>/dev/null || echo "")"
    CUR_GID="$(stat -c %g "$DATA_DIR" 2>/dev/null || echo "")"
    if [ "${CUR_UID}" != "${PUID}" ] || [ "${CUR_GID}" != "${PGID}" ]; then
        chown -R "${PUID}:${PGID}" "$DATA_DIR"
    fi
    set -- su-exec "${PUID}:${PGID}" "$@"
fi

exec "$@"
