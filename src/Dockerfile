# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS base

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -yq && apt-get install -yq --no-install-recommends \
    ca-certificates \
    curl \
    makeself

ARG ANSIBLE_RELEASE=10.0
ENV ANSIBLE_RELEASE=${ANSIBLE_RELEASE}

ARG PYTHON_RELEASE=20240415
ENV PYTHON_RELEASE=${PYTHON_RELEASE}

ARG PYTHON_VERSION=3.11.9
ENV PYTHON_VERSION=${PYTHON_VERSION}

WORKDIR /opt

RUN PYTHON="cpython-${PYTHON_VERSION}+${PYTHON_RELEASE}-$(uname -m)-unknown-linux-gnu-install_only.tar.gz" && \
    curl -fsSLo "${PYTHON}" "https://github.com/indygreg/python-build-standalone/releases/download/${PYTHON_RELEASE}/${PYTHON}" && \
    tar xzf "${PYTHON}" && \
    rm -f "${PYTHON}" && \
    mv python getansible

FROM base AS build
RUN getansible/bin/pip install -q --upgrade ansible~="${ANSIBLE_RELEASE}"
RUN sed -i 's|#!/opt/getansible/bin/python3.*|#!/usr/bin/env python3|' /opt/getansible/bin/ansible*
COPY --chmod=0755 entrypoint.sh /opt/getansible/entrypoint.sh
RUN rm -r /opt/getansible/share/ && \
    find /opt/getansible -type d -name "__pycache__" -print | xargs rm -rf && \
    find /opt/getansible -type d -name "tests" -print | xargs rm -rf

RUN makeself \
    --complevel 6 \
    --tar-format gnu \
    --tar-quietly \
    --tar-extra '--mtime=2024-01-01' \
    --packaging-date '2024-01-01T00:00:00Z' \
    /opt/getansible \
    /opt/getansible.sh \
    "Ansible ${ANSIBLE_RELEASE} (Python ${PYTHON_VERSION})" \
    ./entrypoint.sh
RUN chmod 0755 /opt/getansible.sh

FROM scratch AS release

ARG ANSIBLE_RELEASE
ARG TARGETARCH

COPY --from=build --chown=root:root --chmod=0755 /opt/getansible.sh /getansible-$ANSIBLE_RELEASE-$TARGETARCH.sh
