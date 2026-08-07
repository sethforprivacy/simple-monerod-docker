# Simple Monerod Docker

A simple and straightforward Dockerized monerod built from source and exposing standard ports.

## Actions

[![Latest Dockerfile build on push](https://github.com/sethforprivacy/simple-monerod-docker/actions/workflows/update-image-on-push.yml/badge.svg)](https://github.com/sethforprivacy/simple-monerod-docker/actions/workflows/update-image-on-push.yml)  

## Tags

I will always release the latest Monero version under the `latest` tag as well as the version number tag (i.e. `v0.18.0.0`).

`latest`: The latest tagged version of Monero from https://github.com/monero-project/monero/tags, built on an Alpine base image  
`vx.xx.x.x`: The version corresponding with the tagged version from https://github.com/monero-project/monero/tags, built on an Alpine base image  

## Recommended usage

I am using this container for my guide on running a Monero node:

https://sethforprivacy.com/guides/run-a-monero-node/

The ways I would generally recommend running this container for a personal or public Monero node are below.

monerod Docker w/o public RPC:

```bash
sudo docker run -d --restart unless-stopped --name="monerod" -v bitmonero:/home/monero/.bitmonero ghcr.io/sethforprivacy/simple-monerod:latest --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --no-igd --no-zmq --enable-dns-blocklist --ban-list=/home/monero/ban_list.txt
```

monerod Docker w/ public RPC:

```bash
sudo docker run -d --restart unless-stopped --name="monerod" -v bitmonero:/home/monero/.bitmonero ghcr.io/sethforprivacy/simple-monerod:latest  --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --public-node --no-igd --no-zmq --enable-dns-blocklist --ban-list=/home/monero/ban_list.txt
```

monerod Docker w/o public RPC (pruned):

```bash
sudo docker run -d --restart unless-stopped --name="monerod" -v bitmonero:/home/monero/.bitmonero ghcr.io/sethforprivacy/simple-monerod:latest  --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --no-igd --no-zmq --enable-dns-blocklist --ban-list=/home/monero/ban_list.txt --prune-blockchain
```

monerod Docker w/ public RPC (pruned):

```bash
sudo docker run -d --restart unless-stopped --name="monerod" -v bitmonero:/home/monero/.bitmonero ghcr.io/sethforprivacy/simple-monerod:latest  --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --public-node --no-igd --no-zmq --enable-dns-blocklist --ban-list=/home/monero/ban_list.txt --prune-blockchain
```

Learn more about all available options (flags) to configure monerod: [Monerod Reference Options](https://docs.getmonero.org/interacting/monerod-reference/#options)

## Security: Docker port publishing (0.0.0.0) and UFW

Docker publishes ports on all interfaces by default. If you use `-p` with `docker run` (for example, `-p 18089:18089`) or define `ports:` in `docker-compose.yml` (for example, `- 18089:18089`), Docker binds those ports to `0.0.0.0` unless you explicitly specify a host IP. This makes the service reachable from any network interface on the host.

This can also bypass UFW rules. Docker installs its own iptables rules that accept traffic to published ports before UFW’s filter rules are evaluated. As a result, even if UFW’s default policy is to deny incoming traffic, a published Docker port may still be reachable from the internet.

- If you do not want the restricted RPC exposed publicly, either do not publish it at all or bind it only to localhost:
  - docker run: `-p 127.0.0.1:18089:18089`
  - docker-compose.yml: `ports: ["127.0.0.1:18089:18089"]`
- For a public P2P node, it is normal to publish `18080`. Be deliberate about whether `18089` (restricted RPC) should be public.
- If you are running this container behind a firewall (e.g. at home behind a NAT router), it's usually okay to bind on 0.0.0.0

## Security: hardened container runtime

The example `docker-compose.yml` applies what hardening is compatible with this image's [fixuid](https://github.com/boxboat/fixuid)-based runtime:

| Setting | Effect |
|---------|--------|
| `cap_drop: [ALL]` + `cap_add` of the six capabilities fixuid needs | the container starts with only `CHOWN, FOWNER, DAC_OVERRIDE, SETUID, SETGID, SETPCAP`; once fixuid drops to the unprivileged user, the daemon runs with **zero effective capabilities** |
| `memswap_limit` equal to `memory` (default `MONEROD_MEM_LIMIT=8G`) | a memory-pressure attack cannot spill the node's working set into host swap (Docker would otherwise allow 2x the memory limit). Both are driven by one knob so they always stay equal; raise `MONEROD_MEM_LIMIT` on hosts with more RAM — the zero-swap property holds at any value, and the lmdb page-cache window the node gets is charged to the cgroup, so more headroom helps sync/verify on big machines |
| `pids_limit` (default `MONEROD_PIDS_LIMIT=512`) | bounds processes/threads in the container (monerod spawns a thread per P2P connection; a syncing node uses ~30) |
| `--max-log-file-size=10000000 --max-log-files=7` (also baked into the image's default `CMD`) | caps log file writes — which land in the data volume, i.e. host disk — at 7 × 10 MB instead of monerod's 100 MB × 50 default |

What is **not** applied, and why: this container starts every daemon through `fixuid`, a setuid-root binary that remaps the `monero` user to your host uid (or the owner of the data volume) by rewriting `/etc/passwd` and chowning the volume on first start. That makes three otherwise-standard hardening flags unsafe here:

- `no-new-privileges: true` — blocks fixuid's setuid execution (fixuid exits, container fails).
- `read_only: true` — fixuid must write `/etc/passwd` and `/var/run/fixuid.ran` on the root filesystem.
- `cap_drop: [ALL]` (complete) — fixuid's remapping needs `CHOWN`/`DAC_OVERRIDE`/`SETUID`/`SETGID` etc.

All three were tested against a running container: each makes the container exit at startup, so they must stay off while fixuid is in the entrypoint.

## Running as a different user

In situations where you need the daemon to be run as a different user, I have added [fixuid](https://github.com/boxboat/fixuid) to enable that. Much of the work for this was taken from [docker-monero](https://github.com/cornfeedhobo/docker-monero), and enables you to specify a new user/group in your `docker run` or `docker-compose.yml` file to run as a different user.

- In `docker run` commands, you can specify the user like this: `--user 1000:1000`
- In `docker-compose.yml` files, you can specify the user like this: `user: ${FIXUID:-1000}:${FIXGID:-1000}`

A great use-case for this is running with the daemon's files stored on an NFS mount, or running monerod on a Synology NAS.

## Copyrights

Code from this repository is released under MIT license. [Monero License](https://github.com/monero-project/monero/blob/master/LICENSE), [@leonardochaia License](https://github.com/leonardochaia/docker-monerod/blob/master/LICENSE)

## Credits

The base for the Dockerfile was pulled from:

https://github.com/leonardochaia/docker-monerod

The migration to Alpine from a Ubuntu 20.04 base image was based largely on previous commits from:

https://github.com/cornfeedhobo/docker-monero
