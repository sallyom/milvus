FROM registry.access.redhat.com/ubi9/ubi:9.4-947.1717074712 as vcpkg-installer

RUN dnf install -y wget zip git gcc gcc-c++ cmake \
        dnf-plugins-core ninja-build \
        perl-IPC-Cmd perl-Digest-SHA \
        perl-FindBin perl-File-Compare perl-File-Copy 

ENV VCPKG_FORCE_SYSTEM_BINARIES 1

RUN mkdir /opt/vcpkg &&  \
    wget -qO- vcpkg.tar.gz https://github.com/microsoft/vcpkg/archive/refs/tags/2023.11.20.tar.gz | tar --strip-components=1 -xz -C /opt/vcpkg && \
    rm -rf vcpkg.tar.gz

# empty the vscpkg toolchains linux.cmake file to avoid the error
RUN echo "" > /opt/vcpkg/scripts/toolchains/linux.cmake

# install azure-identity-cpp azure-storage-blobs-cpp gtest via vcpkg
RUN /opt/vcpkg/bootstrap-vcpkg.sh -disableMetrics && \
    ln -s /opt/vcpkg/vcpkg /usr/local/bin/vcpkg && \
    vcpkg version && \
    vcpkg install azure-identity-cpp azure-storage-blobs-cpp gtest


#FROM nvcr.io/nvidia/cuda:12.4.1-devel-ubi9
FROM registry.access.redhat.com/ubi9/ubi:9.4-947.1717074712 as builder

ARG TARGETARCH

RUN --mount=type=secret,id=subman_creds source /run/secrets/subman_creds &&  subscription-manager register --username ${SUBMAN_USER} --password ${SUBMAN_PASS} && \
    dnf install -y \
        https://www.rpmfind.net/linux/centos-stream/9-stream/AppStream/x86_64/os/Packages/perl-Unicode-EastAsianWidth-12.0-7.el9.noarch.rpm \
        https://www.rpmfind.net/linux/centos-stream/9-stream/AppStream/x86_64/os/Packages/perl-Text-Unidecode-1.30-16.el9.noarch.rpm \
        https://www.rpmfind.net/linux/centos-stream/9-stream/AppStream/x86_64/os/Packages/perl-libintl-perl-1.32-4.el9.x86_64.rpm \
        https://www.rpmfind.net/linux/centos-stream/9-stream/CRB/x86_64/os/Packages/texinfo-6.7-15.el9.x86_64.rpm

RUN dnf group install "Development Tools" -y && \
    dnf install -y --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
    git \
    gcc \
    gcc-c++ \
    make \
    #cmake \
    automake \
    libtool \
    pkgconfig \
    wget \
    unzip \
    tar \
    bzip2 \
    openssl-devel \
    libaio \
    libaio-devel \
    libstdc++-static \
    llvm-toolset \
    ninja-build \
    openblas \
    openblas-devel \
    zip unzip \
    zlib-devel \
    libcurl-devel \
    libuuid-devel \
    perl-IPC-Cmd perl-Digest-SHA perl-FindBin \
    python3-pip && \
    pip3 install --upgrade pip && \
    pip3 install conan==1.64.1 && \
    dnf clean all && \
    subscription-manager unregister && \
    rm -rf /var/cache/dnf

WORKDIR /milvus

# Install cmake version 3.27, upstream uses this version, and the 'dnf install cmake' version fails
RUN wget -qO- "https://cmake.org/files/v3.27/cmake-3.27.5-linux-`uname -m`.tar.gz" | tar --strip-components=1 -xz -C /usr/local

# Install go
RUN mkdir -p /usr/local/go && wget -qO- "https://go.dev/dl/go1.23.3.linux-$TARGETARCH.tar.gz" | tar --strip-components=1 -xz -C /usr/local/go
ENV PATH=$PATH:/usr/local/go/bin

# Install rust
RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- --default-toolchain=1.73 -y
ENV PATH=/root/.cargo/bin:/usr/local/bin:/usr/local/go/bin:$PATH

COPY --from=vcpkg-installer /root/.cache/vcpkg /milvus/.cache/vcpkg

COPY --chown=0:0 build/docker/builder/entrypoint.sh /

# Option - Add Include Path instead of symlinks below?
#ENV CMAKE_INCLUDE_PATH=/usr/include/openblas:$CMAKE_INCLUDE_PATH
RUN for file in /usr/include/openblas/*; do \
      ln -s "$file" /usr/include/"$(basename "$file")"; \
    done

RUN /entrypoint.sh

COPY . .

RUN cp /milvus/build/docker/milvus/rhel9/configs/* /milvus/configs/. && make install

FROM registry.access.redhat.com/ubi9/ubi:9.4-947.1717074712

ARG TARGETARCH

RUN --mount=type=secret,id=subman_creds \
    source /run/secrets/subman_creds && \
    subscription-manager register --username "$SUBMAN_USER" --password "$SUBMAN_PASS" && \
    subscription-manager attach --auto && \
    dnf install -y --enablerepo=codeready-builder-for-rhel-9-x86_64-rpms \
    ca-certificates \
    libaio \
    libaio-devel \
    libgomp \
    openblas \
    openblas-devel && \
    dnf clean all && \
    subscription-manager unregister && \
    rm -rf /var/cache/dnf

WORKDIR /milvus

RUN curl -L -o /milvus/tini https://github.com/krallin/tini/releases/download/v0.19.0/tini-$TARGETARCH && \
    chmod +x /milvus/tini

COPY --chmod=774 --from=builder /milvus/bin/ /milvus/bin/
COPY --chmod=774 --from=builder /milvus/configs/ /milvus/configs/
COPY --chmod=774 --from=builder /milvus/lib/ /milvus/lib/

ENV PATH=/milvus/bin:$PATH
ENV LD_LIBRARY_PATH=/milvus/lib:$LD_LIBRARY_PATH:/usr/lib
ENV LD_PRELOAD=/milvus/lib/libjemalloc.so
ENV MALLOC_CONF=background_thread:true
ENV ETCD_USE_EMBED=true
ENV ETCD_CONFIG_PATH=/milvus/configs/embedEtcd.yaml
ENV COMMON_STORAGETYPE=local

ENTRYPOINT ["/milvus/tini", "--"]
