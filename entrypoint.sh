#!/bin/sh
# Credit for the bulk of this entrypoint script goes to cornfeedhobo
# Source is https://github.com/cornfeedhobo/docker-monero/blob/master/entrypoint.sh
set -e

# Set require --non-interactive flag
set -- "monerod" "--non-interactive" "$@"

# Configure NUMA interleaving only when the kernel actually supports it:
# numactl exits nonzero on non-NUMA systems, which would kill the container.
if command -v numactl >/dev/null 2>&1 && numactl --show >/dev/null 2>&1; then
    set -- numactl --interleave=all "$@"
fi
# Start the daemon using fixuid
# to adjust permissions if needed
exec fixuid -q "$@"
