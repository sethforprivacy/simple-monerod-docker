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
