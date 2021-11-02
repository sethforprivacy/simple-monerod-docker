# simple-monerod-docker
A simple and straightforward Dockerized monerod built from source and exposing standard ports.

## Actions

[![Weekly Update Rebuild](https://github.com/sethsimmons/simple-monerod-docker/actions/workflows/update-base-image.yml/badge.svg)](https://github.com/sethsimmons/simple-monerod-docker/actions/workflows/update-base-image.yml) 
[![Latest Dockerfile build](https://github.com/sethsimmons/simple-monerod-docker/actions/workflows/update-image-on-push.yml/badge.svg)](https://github.com/sethsimmons/simple-monerod-docker/actions/workflows/update-image-on-push.yml)  
[![Container security scan with Trivy](https://github.com/sethsimmons/simple-monerod-docker/actions/workflows/trivy-analysis.yml/badge.svg)](https://github.com/sethsimmons/simple-monerod-docker/actions/workflows/trivy-analysis.yml)

## Docker

![Docker Pulls](https://img.shields.io/docker/pulls/sethsimmons/simple-monerod)  
![Docker Image Size (latest by date)](https://img.shields.io/docker/image-size/sethsimmons/simple-monerod)  
![Docker Image Version (latest by date)](https://img.shields.io/docker/v/sethsimmons/simple-monerod)  

# Docker Hub
This repo is used to build the images available at:

https://hub.docker.com/r/sethsimmons/simple-monerod

# Tags
I will always release the latest Monero version under the `latest` tag as well as the version number tag (i.e. `v0.17.1.9`).

`latest`: The latest tagged version of Monero from https://github.com/monero-project/monero/tags  
`vx.xx.x.x`: The version corresponding with the tagged version from https://github.com/monero-project/monero/tags

# Recommended usage

I am using this container for my guide on running a Monero node:

https://sethforprivacy.com/guides/run-a-monero-node/

The ways I would generally recommend running this container for a personal or public Monero node are below.

monerod Docker w/o public RPC:

```
sudo docker run -d --restart unless-stopped --name="monerod" -v bitmonero:/home/monero/.bitmonero sethsimmons/simple-monerod:latest --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --no-igd --no-zmq --enable-dns-blocklist
```

monerod Docker w/ public RPC:
```
sudo docker run -d --restart unless-stopped --name="monerod" -v bitmonero:/home/monero/.bitmonero sethsimmons/simple-monerod:latest  --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --public-node --no-igd --no-zmq --enable-dns-blocklist
```

monerod Docker w/o public RPC (pruned):
```
sudo docker run -d --restart unless-stopped --name="monerod" -v bitmonero:/home/monero/.bitmonero sethsimmons/simple-monerod:latest  --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --no-igd --no-zmq --enable-dns-blocklist --prune-blockchain
```

monerod Docker w/ public RPC (pruned):
```
sudo docker run -d --restart unless-stopped --name="monerod" -v bitmonero:/home/monero/.bitmonero sethsimmons/simple-monerod:latest  --rpc-restricted-bind-ip=0.0.0.0 --rpc-restricted-bind-port=18089 --public-node --no-igd --no-zmq --enable-dns-blocklist --prune-blockchain
```

# Copyrights

Code from this repository is released under MIT license. [Monero License](https://github.com/monero-project/monero/blob/master/LICENSE), [@leonardochaia License](https://github.com/leonardochaia/docker-monerod/blob/master/LICENSE)

# Credits
The base for the Dockerfile was pulled from:

https://github.com/leonardochaia/docker-monerod
