# `getansible.sh` - self-contained, standalone, and reproducible Ansible installation

[![Release - getansible.sh](https://github.com/andreygubarev/getansible/actions/workflows/github-release.yml/badge.svg?branch=main)](https://github.com/andreygubarev/getansible/actions/workflows/github-release.yml)

## Getting started

Use `getansible.sh` to run Ansible playbooks:
```bash
sh <(curl -sL getansible.sh) geerlingguy.docker
```

Install `getansible.sh` using `curl`:
```bash
sh <(curl -sL getansible.sh)
```

After that run Ansible roles directly:
```bash
getansible.sh -- geerlingguy.docker
```

### Overview

`getansible.sh` is a shell script that contains a self-extracting archive of Ansible (including dependencies) and Python interpreter. It is designed to be executed on any Linux machine without the need to install packages or dependencies.

Supported Ansible Versions:

| Release | Ansible | Ansible Core | Python |
|---------|---------|--------------|--------|
| 9.0     | 9.5.1   | 2.16.6       | 3.11.9 |
| 10.0    | 10.1.0  | 2.17.1       | 3.11.9 |

Supported Linux with GLIBC 2.17 or later:

- `Debian` starting from `8` (`jessie`)
- `Ubuntu` starting from `14.04` (`trusty`)
- `Fedora` starting from `21`
- `openSUSE` starting from `13.2`
- `RHEL` or `CentOS` starting from `7`

Note: Linux distributions with MUSL (e.g. `Alpine`) are not supported.

Supported Platforms:

- `amd64`
- `arm64`

### Prerequisites

`getansible.sh` requires `bash`, `curl`, `sed` and `tar` to be installed on the system. Ansible requires locale to be installed and configued.

```bash
apt-get update && apt-get install -yq --no-install-recommends \
    ca-certificates \
    curl \
    locales-all
```

`getansible.sh` requires at least 1GB of free space in the temporary directory. You may need to change default `TMPDIR` if you have limited space in `/tmp`.

## Support for Ansible sources
`getansible.sh` supports multiple sources for Ansible playbooks and roles.

### Ansible Galaxy sources

`getansible.sh` supports Ansible Galaxy sources:
```bash
# Ansible Role: https://galaxy.ansible.com/ui/standalone/roles/geerlingguy/docker/
getansible.sh -- geerlingguy.docker

# Ansible Role from Collection: https://galaxy.ansible.com/ui/repo/published/andreygubarev/actions/content/role/ssh/
getansible.sh -- andreygubarev.actions.ssh
```

### Github sources

`getansible.sh` supports Github repositories with special naming convention:
`<user>/ansible-collection-actions` (e.g https://github.com/andreygubarev/ansible-collection-actions) and support shortcut syntax for playbooks execution:

```bash
# https://github.com/andreygubarev/ansible-collection-actions/blob/main/playbooks/setup-ssh.yml
getansible.sh -- @andreygubarev/setup-ssh
```

## Local sources

For tarball sources, use following file structure is expected inside the tarball:
```
.
├── .env
├── ansible.cfg
├── hosts.yml
├── playbook.yml
├── requirements.txt
├── requirements.yml
└── roles
    └── role_name
        └── tasks
            └── main.yml
```

Where:
- `.env` - Environment variables for the playbook
- `ansible.cfg` - Ansible configuration file
- `hosts.yml` - Inventory file
- `playbook.yml` - Main playbook file (required)
- `requirements.txt` - Python requirements file
- `requirements.yml` - Ansible Galaxy requirements file
- `roles` - Directory with roles

## Configuration

You can configure the following environment variables:

`GETANSIBLE_PATH` - Path to install `getansible.sh` (default: `/usr/local/bin/getansible.sh`):
```bash
GETANSIBLE_PATH=/opt/getansible.sh sh <(curl -sL getansible.sh) install
```

`ANSIBLE_RELEASE` - Ansible release to install (default: `9.0`):
```bash
ANSIBLE_RELEASE=9.0 sh <(curl -sL getansible.sh) install
```

`PYTHON_REQUIREMENTS` - Python requirements needed for your playbook (default: `''`):
```bash
PIP_REQUIREMENTS='boto3 botocore' sh <(curl -sL getansible.sh) ansible --version
```

`TMPDIR` - Temporary directory to extract Ansible (default: `/tmp`):
```bash
TMPDIR=/opt/ sh <(curl -sL getansible.sh) ansible --version
```

## Motivation

Author always wanted Ansible to be distributed as a single binary, so it can be easily executed on any Linux machine without the need to install packages or dependencies.

Setting up Ansible using package manager means sticking to the version provided by the OS, which always lags behind the latest release. Setting up Ansible using Python package manager means relying on the PYPI repository, which may be down.

Thus, `getansible.sh` was created to provide a self-contained, standalone (isolated and portable), and reproducible Ansible installation.

### Criticism of Curl Piping

- https://0x46.net/thoughts/2019/04/27/piping-curl-to-shell/
- https://gnu.moe/wallofshame.md

Author believes that curl piping is acceptable for downloading and executing scripts, as long as the script is open-source and the source code is available for review. In this case, transparency is sufficient to ensure good faith.

For those who are still concerned (and rightfully so), `getansible.sh` can be downloaded directly from the [releases page](https://github.com/andreygubarev/getansible/releases) and executed locally.

# Reference

The project is possible only because of the following tools:

- [Ansible](https://www.ansible.com/)
- [Makeself](https://makeself.io/)
- [python-build-standalone](https://github.com/indygreg/python-build-standalone)

Additional references:

- [Ansible Releases Explained](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html)
- [Linux Support Explained](https://gregoryszorc.com/docs/python-build-standalone/20220227/running.html#linux)
- [Python Lifecycle](https://devguide.python.org/versions/#versions)
