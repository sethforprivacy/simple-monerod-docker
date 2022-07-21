#!/bin/ash
# Credit for the bulk of this entrypoint script goes to cornfeedhobo
# Source is https://github.com/cornfeedhobo/docker-monero/blob/master/entrypoint.sh
set -e

# Set require --non-interactive flag
set -- monerod --non-interactive "$@"

# Configure NUMA if present for improved performance
numa='numactl --interleave=all'
if $numa true &> /dev/null; then
	set -- $numa "$@"
fi
# Start the daemon using fixuid
# to adjust permissions if needed
exec fixuid -q "$@"