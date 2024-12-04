## HOW TO BUILD

### Export subscription-manager credentials

Export the following environment variables

```bash
export SUBMAN_USER=your-rh-username
export SUBMAN_PASS=your-rh-password
```

### Build Milvus image

The following environment variables can be set for the build, shown here with defaults:

```
MILVUS_IMAGE_REPO="${MILVUS_IMAGE_REPO:-quay.io/redhat-et/milvus}"
MILVUS_IMAGE_TAG="${MILVUS_IMAGE_TAG:-standalone-rhel94}"
IMAGE_ARCH="${IMAGE_ARCH:-amd64}"
RHTARGETARCH="${RHTARGETARCH:-x86_64}"
BUILD_ARGS="${BUILD_ARGS:---build-arg TARGETARCH=${IMAGE_ARCH} --build-arg RHTARGETARCH=${RHTARGETARCH}}"
```

Run the following from the root of the repository.

```bash
sudo su
./build/ubi_rhel_standalone_image_sub.sh
```

Copy image to rootless storage (milvus doesn't need to run with privileged user)

```bash
sudo podman save -o milvus-image.tar "${MILVUS_IMAGE_REPO}:${MILVUS_IMAGE_TAG}"
podman load -i milvus-image.tar
```

#### Build using podman-remote

```
./build/rhel_standalone_image_sub.sh --remote
```

The build takes a long time depending on your system, ~1hr

## HOW TO RUN

### Run standalone milvus service

Create the milvus data volume

```bash
mkdir -p volumes/milvus
```

Run milvus standalone

```bash
podman run --rm -d \
    --name milvus-standalone \
    --security-opt seccomp:unconfined \
    -v $(pwd)/volumes/milvus:/var/lib/milvus:Z  \
    -p 19530:19530 \
    -p 9091:9091 \
    -p 2379:2379 \
    -e ETCD_DATA_DIR=/var/lib/milvus/etcd \
    --health-cmd="curl -f http://localhost:9091/healthz" \
    --health-interval=30s \
    --health-start-period=90s \
    --health-timeout=20s \
    --health-retries=3 \
    quay.io/redhat-et/milvus:standalone-rhel94 \
    milvus run standalone
```
