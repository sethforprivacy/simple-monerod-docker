# From https://github.com/leonardochaia/docker-monerod/blob/master/src/Dockerfile
# Set Monero branch or tag to build
ARG MONERO_BRANCH=v0.17.3.2

# Set the proper HEAD commit hash for the given branch/tag in MONERO_BRANCH
ARG MONERO_COMMIT_HASH=424e4de16b98506170db7b0d7d87a79ccf541744

# Select Ubuntu 20.04LTS for the build image base
FROM ubuntu:20.04 as build
LABEL author="sethsimmons@pm.me" \
      maintainer="sethsimmons@pm.me"

# Dependency list from https://github.com/monero-project/monero#compiling-monero-from-source
# Added DEBIAN_FRONTEND=noninteractive to workaround tzdata prompt on installation
RUN apt-get update \
    && apt-get upgrade -y \
    && DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends build-essential cmake \
    pkg-config libboost-all-dev libssl-dev libzmq3-dev libunbound-dev ca-certificates \
    libsodium-dev libunwind8-dev liblzma-dev libreadline6-dev libldns-dev \
    libexpat1-dev doxygen graphviz libpgm-dev qttools5-dev-tools libhidapi-dev \
    libusb-dev libprotobuf-dev protobuf-compiler libgtest-dev git \
    libnorm-dev libpgm-dev libusb-1.0-0-dev libudev-dev libgssapi-krb5-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set necessary args and environment variables for building Monero
ARG MONERO_BRANCH
ARG MONERO_COMMIT_HASH
ARG NPROC
ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC'
ENV USE_SINGLE_BUILDDIR 1
ENV BOOST_DEBUG         1

# Switch to Monero source directory
WORKDIR /monero

# Git pull Monero source at specified tag/branch
# Make static Monero binaries
RUN git clone --recursive --branch ${MONERO_BRANCH} \
    https://github.com/monero-project/monero . \
    && test `git rev-parse HEAD` = ${MONERO_COMMIT_HASH} || exit 1 \
    && git submodule init && git submodule update \
    && mkdir -p build/release && cd build/release \
    && cmake -D STATIC=ON -D BUILD_64=ON -D CMAKE_BUILD_TYPE=Release ../.. \
    && cd /monero && nice -n 19 ionice -c2 -n7 make -j${NPROC:-$(nproc)} -C build/release daemon

# Select Ubuntu 20.04LTS for the image base
FROM ubuntu:20.04

# Install remaining dependencies
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install --no-install-recommends -y curl libnorm-dev libpgm-dev libgssapi-krb5-2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add user and setup directories for monerod
RUN useradd -ms /bin/bash monero \
    && mkdir -p /home/monero/.bitmonero \
    && chown -R monero:monero /home/monero/.bitmonero
USER monero

# Switch to home directory and install newly built monerod binary
WORKDIR /home/monero
COPY --chown=monero:monero --from=build /monero/build/release/bin/monerod /usr/local/bin/monerod

# Expose p2p and restricted RPC ports
EXPOSE 18080
EXPOSE 18089

# Add HEALTHCHECK against get_info endpoint
HEALTHCHECK --interval=30s --timeout=5s CMD curl --fail http://localhost:18089/get_info || exit 1

# Start monerod with required --non-interactive flag and sane defaults that are overridden by user input (if applicable)
ENTRYPOINT ["monerod", "--non-interactive"]
CMD ["--rpc-restricted-bind-ip=0.0.0.0", "--rpc-restricted-bind-port=18089", "--no-igd", "--no-zmq", "--enable-dns-blocklist"]
