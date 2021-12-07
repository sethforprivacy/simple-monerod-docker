# From https://github.com/leonardochaia/docker-monerod/blob/master/src/Dockerfile
ARG MONERO_BRANCH=v0.17.3.0
ARG MONERO_COMMIT_HASH=ab18fea3500841fc312630d49ed6840b3aedb34d

# Select Alpine 3.13 for the build image base
FROM alpine:3.13 as build
LABEL author="seth@sethforprivacy.com" \
      maintainer="seth@sethforprivacy.com"

RUN set -ex && apk --update --no-cache upgrade && apk add --update --no-cache \
    autoconf \
    automake \
    boost \
    boost-atomic \
    boost-build \
    boost-build-doc \
    boost-chrono \
    boost-container \
    boost-context \
    boost-contract \
    boost-coroutine \
    boost-date_time \
    boost-dev \
    boost-doc \
    boost-fiber \
    boost-filesystem \
    boost-graph \
    boost-iostreams \
    boost-libs \
    boost-locale \
    boost-log \
    boost-log_setup \
    boost-math \
    boost-prg_exec_monitor \
    boost-program_options \
    boost-python3 \
    boost-random \
    boost-regex \
    boost-serialization \
    boost-stacktrace_basic \
    boost-stacktrace_noop \
    boost-static \
    boost-system \
    boost-thread \
    boost-timer \
    boost-type_erasure \
    boost-unit_test_framework \
    boost-wave \
    boost-wserialization \
    ca-certificates \
    cmake \
    curl \
    dev86 \
    doxygen \
    eudev-dev \
    file \
    g++ \
    git \
    graphviz \
    libexecinfo-dev \
    libsodium-dev \
    libtool \
    libusb-dev \
    linux-headers \
    make \
    miniupnpc-dev \
    ncurses-dev \
    openssl-dev \
    pcsc-lite-dev \
    pkgconf \
    protobuf-dev \
    rapidjson-dev \
    readline-dev \
    unbound-dev \
    zeromq-dev

ARG NPROC
ENV CFLAGS='-fPIC'
ENV CXXFLAGS='-fPIC -DELPP_FEATURE_CRASH_LOG'
ENV USE_SINGLE_BUILDDIR 1
ENV BOOST_DEBUG         1

# Switch to Monero source directory
WORKDIR /monero

# Git pull Monero source at specified tag/branch
ARG MONERO_BRANCH
ARG MONERO_COMMIT_HASH
RUN set -ex && git clone --recursive --branch ${MONERO_BRANCH} \
    https://github.com/monero-project/monero . \
    && test `git rev-parse HEAD` = ${MONERO_COMMIT_HASH} || exit 1 \
    && git submodule init && git submodule update

# Make static Monero binaries
ARG NPROC
RUN set -ex && test -z "$NPROC" && nproc > /nproc || echo -n "$NPROC" > /nproc && make -j"$(cat /nproc)" release-static-linux-x86_64

# Select Alpine 3.13 for the image base
FROM alpine:3.13

# Install remaining dependencies
RUN set -ex && apk --update --no-cache upgrade && apk add --update --no-cache \
    ca-certificates \
    libexecinfo \
    libsodium \
    ncurses-libs \
    pcsc-lite-libs \
    readline \
    zeromq

# Add user and setup directories for monerod
RUN set -ex && adduser -Ds /bin/bash monero \
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
