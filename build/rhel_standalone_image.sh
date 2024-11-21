#!/bin/bash

# Licensed to the LF AI & Data foundation under one
# or more contributor license agreements. See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership. The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License. You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

IMAGE_ARCH="${IMAGE_ARCH:-amd64}"
OS_NAME="${OS_NAME:-rhel9}"
MILVUS_IMAGE_REPO="${MILVUS_IMAGE_REPO:-quay.io/redhat-et/milvus}"
MILVUS_IMAGE_TAG="${MILVUS_IMAGE_TAG:-standalone-rhel94}"

TMPFILE=$(mktemp)
SECRET_NAME=subman_creds
PODMAN=podman

if [[ "${1:-}" == "--remote" ]]; then
    PODMAN=podman-remote
fi

trap 'cleanup' EXIT

cleanup() {
    echo "Cleaning up..."

    if [[ -f "$TMPFILE" ]]; then
        shred -u ${TMPFILE}
    fi

    if ${PODMAN} secret inspect ${SECRET_NAME} >/dev/null 2>&1; then
        ${PODMAN} secret rm ${SECRET_NAME}
        echo "Podman secret $SECRET_NAME removed."
    fi
}

if [ -z "$IMAGE_ARCH" ]; then
    MACHINE=$(uname -m)
    if [ "$MACHINE" = "x86_64" ]; then
        IMAGE_ARCH="amd64"
    else
        IMAGE_ARCH="arm64"
    fi
fi

echo ${IMAGE_ARCH}

BUILD_ARGS="${BUILD_ARGS:---build-arg TARGETARCH=${IMAGE_ARCH}}"

echo "SUBMAN_USER=$SUBMAN_USER" > ${TMPFILE}
echo "SUBMAN_PASS=$SUBMAN_PASS" >> ${TMPFILE}

${PODMAN} secret create ${SECRET_NAME} ${TMPFILE}

${PODMAN} build --secret id=${SECRET_NAME},src=${TMPFILE} --network host ${BUILD_ARGS} --platform linux/${IMAGE_ARCH} -f "./build/docker/milvus/${OS_NAME}/Dockerfile" -t "${MILVUS_IMAGE_REPO}:${MILVUS_IMAGE_TAG}" .
