# syntax=docker/dockerfile:1
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -yq && apt-get install -yq --no-install-recommends \
    bats \
    bats-assert \
    bats-support \
    ca-certificates \
    curl \
    tini

VOLUME /usr/src/bats

ENTRYPOINT ["tini", "--", "bash", "bats"]
