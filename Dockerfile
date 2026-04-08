# renovate: datasource=github-releases depName=monero-project/monero
ARG MONERO_BRANCH=v0.18.4.6
ARG MONERO_COMMIT_HASH=dbcc7d212c094bd1a45f7291dbb99a4b4627a96d

# Use Alpine with SHA256 digest for reproducible builds
# alpine:3.23.3
FROM alpine:3.23.3@sha256:2c43a33b61705f7587ca36f8c6a82a75d50410f71c8c73abf5b097ee5a8bcf2e AS build
LABEL org.opencontainers.image.title="simple-monerod-docker" \
      org.opencontainers.image.description="A simple Docker container for running a Monero node" \
      org.opencontainers.image.source="https://github.com/sethforprivacy/simple-monerod-docker" \
      org.opencontainers.image.licenses="MIT"
LABEL author="seth@sethforprivacy.com" \
      maintainer="seth@sethforprivacy.com"

# Install build dependencies in a single layer
# NOTE: Removed 'apk upgrade' to ensure reproducible builds
# The base image should be updated instead via renovate
RUN set -ex && apk add --no-cache \
    autoconf automake bison boost boost-atomic boost-build \
    boost-build-doc boost-chrono boost-container boost-context \
    boost-contract boost-coroutine boost-date_time boost-dev \
    boost-doc boost-fiber boost-filesystem boost-graph \
    boost-iostreams boost-libs boost-locale boost-log \
    boost-log_setup boost-math boost-prg_exec_monitor \
    boost-program_options boost-python3 boost-random \
    boost-regex boost-serialization boost-stacktrace_basic \
    boost-stacktrace_noop boost-static boost-system boost-thread \
    boost-timer boost-type_erasure boost-unit_test_framework \
    boost-wave boost-wserialization ca-certificates cmake curl \
    dev86 doxygen eudev-dev file flex g++ git graphviz gnupg \
    libsodium-dev libtool libusb-dev linux-headers make \
    miniupnpc-dev ncurses-dev openssl-dev pcsc-lite-dev \
    pkgconf protobuf-dev rapidjson-dev readline-dev zeromq-dev

# Set build environment
ARG MONERO_BRANCH
ARG MONERO_COMMIT_HASH
ARG NPROC
ARG TARGETARCH
ENV CFLAGS='-fPIC' CXXFLAGS='-fPIC' USE_SINGLE_BUILDDIR=1 BOOST_DEBUG=1

WORKDIR /tmp

# Build expat (dependency for libunbound)
# renovate: datasource=github-release-attachments depName=libexpat/libexpat versioning=semver-coerced
ARG EXPAT_VERSION=R_2_6_4
ARG EXPAT_CHECKSUM=8dc480b796163d4436e6f1352e71800a774f73dbae213f1860b60607d2a83ada
RUN set -ex && EXPAT_SEMVER="$(echo ${EXPAT_VERSION} | sed 's/R_//;s/_/./g')" && \
    wget -q "https://github.com/libexpat/libexpat/releases/download/${EXPAT_VERSION}/expat-${EXPAT_SEMVER}.tar.bz2" && \
    echo "${EXPAT_CHECKSUM}  expat-${EXPAT_SEMVER}.tar.bz2" | sha256sum -c && \
    tar -xf expat-${EXPAT_SEMVER}.tar.bz2 && rm expat-${EXPAT_SEMVER}.tar.bz2 && \
    cd expat-${EXPAT_SEMVER} && \
    ./configure --enable-static --disable-shared --prefix=/usr && \
    make -j${NPROC:-$(nproc)} && make install && \
    cd /tmp && rm -rf expat-${EXPAT_SEMVER}

# Build libunbound for static builds
# renovate: datasource=github-release-attachments depName=NLnetLabs/unbound versioning=semver-coerced
ARG LIBUNBOUND_VERSION=release-1.22.0
ARG LIBUNBOUND_CHECKSUM=4e32a36d57cda666b1c8ee02185ba73462330452162d1b9c31a5b91a853ba946
RUN set -ex && \
    wget -q "https://github.com/NLnetLabs/unbound/archive/refs/tags/${LIBUNBOUND_VERSION}.tar.gz" && \
    echo "${LIBUNBOUND_CHECKSUM}  ${LIBUNBOUND_VERSION}.tar.gz" | sha256sum -c && \
    tar -xzf ${LIBUNBOUND_VERSION}.tar.gz && rm ${LIBUNBOUND_VERSION}.tar.gz && \
    cd unbound-${LIBUNBOUND_VERSION} && \
    ./configure --disable-shared --enable-static --without-pyunbound \
        --with-libexpat=/usr --with-ssl=/usr --with-libevent=no \
        --without-pythonmodule --disable-flto --with-pthreads \
        --with-libunbound-only --with-pic && \
    make -j${NPROC:-$(nproc)} && make install && \
    cd /tmp && rm -rf unbound-${LIBUNBOUND_VERSION}

# Build Monero
WORKDIR /monero
RUN set -ex && git clone --recursive --branch ${MONERO_BRANCH} \
    --depth 1 --shallow-submodules https://github.com/monero-project/monero . && \
    test `git rev-parse HEAD` = ${MONERO_COMMIT_HASH} || exit 1 && \
    case ${TARGETARCH:-amd64} in \
        "arm64") CMAKE_ARCH="armv8-a"; CMAKE_BUILD_TAG="linux-armv8" ;; \
        "amd64") CMAKE_ARCH="x86-64"; CMAKE_BUILD_TAG="linux-x64" ;; \
        *) echo "Unsupported platform: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    mkdir -p build/release && cd build/release && \
    cmake -D ARCH=${CMAKE_ARCH} -D STATIC=ON -D BUILD_64=ON \
        -D CMAKE_BUILD_TYPE=Release -D BUILD_TAG=${CMAKE_BUILD_TAG} \
        -D STACK_TRACE=OFF ../.. && \
    cd /monero && nice -n 19 ionice -c2 -n7 make -j${NPROC:-$(nproc)} -C build/release daemon

# Clone and validate ban list
RUN set -ex && git clone --depth 1 https://github.com/Boog900/monero-ban-list /tmp/ban-list && \
    cd /tmp/ban-list && \
    wget -q https://raw.githubusercontent.com/Cuprate/cuprate/7b8756fa80e386fb04173d8220c15c86bf9f9888/misc/gpg_keys/boog900.asc && \
    wget -q -O rucknium.asc https://rucknium.me/pgp.txt || \
    wget -q -O rucknium.asc https://gist.githubusercontent.com/Rucknium/262526e37732241bb0e676c670b8c60d/raw && \
    wget -q https://raw.githubusercontent.com/monero-project/monero/004ead1a14d60ff757880c5b16b894b526427829/utils/gpg_keys/jeffro256.asc && \
    gpg --import boog900.asc rucknium.asc jeffro256.asc && \
    gpg --verify --status-fd 1 ./sigs/boog900.sig ban_list.txt 2>/dev/null && \
    gpg --verify --status-fd 1 ./sigs/Rucknium.sig ban_list.txt 2>/dev/null && \
    gpg --verify --status-fd 1 ./sigs/jeffro256.sig ban_list.txt 2>/dev/null

# Final stage
FROM alpine:3.23.3@sha256:2c43a33b61705f7587ca36f8c6a82a75d50410f71c8c73abf5b097ee5a8bcf2e AS final
LABEL org.opencontainers.image.title="simple-monerod-docker" \
      org.opencontainers.image.description="A simple Docker container for running a Monero node" \
      org.opencontainers.image.source="https://github.com/sethforprivacy/simple-monerod-docker" \
      org.opencontainers.image.licenses="MIT"

# Install runtime dependencies (removed 'upgrade' for reproducibility)
RUN set -ex && apk add --no-cache \
    curl ca-certificates libsodium ncurses-libs pcsc-lite-libs \
    readline tzdata zeromq

# Create monero user
RUN set -ex && adduser -Ds /bin/ash monero && \
    mkdir -p /home/monero/.bitmonero && \
    chown -R monero:monero /home/monero/.bitmonero

# Copy entrypoint
COPY --chmod=0755 entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

# Install fixuid for proper UID/GID mapping
ARG MONERO_USER="monero"
ARG TARGETARCH
# renovate: datasource=github-releases depName=boxboat/fixuid
ARG FIXUID_VERSION=0.6.0
RUN set -ex && case ${TARGETARCH:-amd64} in \
        "arm64") FIXUID_ARCH="arm64" ;; \
        "amd64") FIXUID_ARCH="amd64" ;; \
        *) echo "Unsupported platform: ${TARGETARCH}"; exit 1 ;; \
    esac && \
    wget -q -O - "https://github.com/boxboat/fixuid/releases/download/v${FIXUID_VERSION}/fixuid-${FIXUID_VERSION}-linux-${FIXUID_ARCH}.tar.gz" | \
    tar -C /usr/local/bin -xzf - && \
    chown root:root /usr/local/bin/fixuid && \
    chmod 4755 /usr/local/bin/fixuid && \
    mkdir -p /etc/fixuid && \
    printf "user: %s\ngroup: %s\n" "${MONERO_USER}" "${MONERO_USER}" > /etc/fixuid/config.yml

USER "${MONERO_USER}:${MONERO_USER}"

# Copy binaries
WORKDIR /home/${MONERO_USER}
COPY --chown=monero:monero --from=build /monero/build/release/bin/monerod /usr/local/bin/monerod
COPY --chown=monero:monero --from=build /tmp/ban-list/ban_list.txt ./ban_list.txt

# Expose ports
EXPOSE 18080 18089

# Healthcheck
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD curl --fail http://127.0.0.1:18081/get_height || exit 1

# Default command
CMD ["--rpc-restricted-bind-ip=0.0.0.0", "--rpc-restricted-bind-port=18089", \
     "--no-igd", "--no-zmq", "--enable-dns-blocklist", \
     "--ban-list=/home/monero/ban_list.txt"]
