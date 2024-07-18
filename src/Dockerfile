# syntax=docker/dockerfile:1

FROM debian:bookworm-slim AS build

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -yq && apt-get install -yq --no-install-recommends \
    ca-certificates \
    curl \
    makeself

ARG ANSIBLE_RELEASE=10.0
ENV ANSIBLE_RELEASE=${ANSIBLE_RELEASE}

ARG PYTHON_RELEASE=20240713
ENV PYTHON_RELEASE=${PYTHON_RELEASE}

ARG PYTHON_VERSION=3.11.9
ENV PYTHON_VERSION=${PYTHON_VERSION}

WORKDIR /usr/local/src
COPY . .
RUN bash ./bin/build.sh

FROM scratch AS release
ARG ANSIBLE_RELEASE
ARG TARGETARCH
COPY --from=build --chown=root:root --chmod=0755 /usr/local/src/dist/* /
