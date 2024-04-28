# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -yq && apt-get install -yq --no-install-recommends \
    ca-certificates \
    curl \
    makeself

ARG ANSIBLE_CORE_VERSION=2.16.6
ENV ANSIBLE_CORE_VERSION=${ANSIBLE_CORE_VERSION}

ARG PYTHON_RELEASE=20240415
ENV PYTHON_RELEASE=${PYTHON_RELEASE}

ARG PYTHON_VERSION=3.12.3
ENV PYTHON_VERSION=${PYTHON_VERSION}

WORKDIR /opt

RUN PYTHON="cpython-${PYTHON_VERSION}+${PYTHON_RELEASE}-$(uname -m)-unknown-linux-gnu-install_only.tar.gz" && \
    curl -fsSLo "${PYTHON}" "https://github.com/indygreg/python-build-standalone/releases/download/${PYTHON_RELEASE}/${PYTHON}" && \
    tar xzf "${PYTHON}" && \
    rm -f "${PYTHON}" && \
    mv python ansiblex

RUN ansiblex/bin/pip install -q --upgrade ansible-core=="${ANSIBLE_CORE_VERSION}"
RUN sed -i 's|#!/opt/ansiblex/bin/python3.12|#!/usr/bin/env python3|' /opt/ansiblex/bin/ansible*
COPY --chmod=0755 ansiblex.sh /opt/ansiblex/ansiblex.sh
RUN rm -r /opt/ansiblex/share/ && \
    find /opt/ansiblex -type d -name "__pycache__" -print | xargs rm -rf && \
    find /opt/ansiblex -type d -name "tests" -print | xargs rm -rf

ENV MAKESELF_ARGS="--complevel 6 --tar-format gnu --tar-quietly"
RUN makeself $MAKESELF_ARGS \
    /opt/ansiblex \
    /opt/ansiblex.run \
    "Ansible ${ANSIBLE_VERSION} with Python ${PYTHON_VERSION}" \
    ./ansiblex.sh
RUN chmod 0755 /opt/ansiblex.run

FROM scratch AS release
ARG TARGETARCH
COPY --from=build --chown=root:root --chmod=0755 /opt/ansiblex.run /ansiblex-$TARGETARCH
