# `getansible.sh` - self-contained, portable, isolated, and reproducible Ansible installation

## Getting Started

```bash
curl -s https://getansible.sh/ | sh -
```

Additionally, you can specify the Ansible release to install:
```bash
curl -s https://getansible.sh/ | ANSIBLE_RELEASE=9.0 sh -
```

Then, you can execute Ansible commands:
```bash
getansible.sh -- ansible-playbook playbook.yml
```

Or, you can execute Ansible commands directly:
```bash
curl -s https://getansible.sh/ | sh -s -- ansible-playbook playbook.yml
```

## Overview

`getansible.sh` is a shell script that contains a self-extracting archive of Ansible (including dependencies) and Python interpreter. It is designed to be executed on any Linux machine without the need to install packages or dependencies.

Supported Ansible Versions:

| Release | Ansible | Ansible Core | Python |
|---------|---------|--------------|--------|
| 3.0     | 3.4.0   | 2.10.17      | 3.8.19 |
| 4.0     | 4.10.0  | 2.11.12      | 3.8.19 |
| 5.0     | 5.10.0  | 2.12.10      | 3.8.19 |
| 6.0     | 6.7.0   | 2.13.13      | 3.8.19 |
| 7.0     | 7.7.0   | 2.14.16      | 3.11.9 |
| 8.0     | 8.7.0   | 2.15.11      | 3.11.9 |
| 9.0     | 9.5.1   | 2.16.6       | 3.11.9 |

Supported Linux with GLIBC 2.17+:

- Debian 8+
- Ubuntu 14.04+
- Fedora 21+
- openSUSE 13.2+
- RHEL/CentOS 7+

Note: Linux distributions with MUSL (e.g. Alpine) are not supported.

Supported Platforms:

- `amd64`
- `arm64`

## Motivation

Author always wanted Ansible to be distributed as a single binary, so it can be easily executed on any Linux machine without the need to install packages or dependencies.

Setting up Ansible using package manager means sticking to the version provided by the OS, which always lags behind the latest release. Setting up Ansible using Python package manager means relying on the PYPI repository, which may be down.

Thus, `getansible.sh` was created to provide a self-contained, portable, isolated, and reproducible Ansible installation.

# Reference

The project is possible only because of the following tools:

- [Ansible](https://www.ansible.com/)
- [Makeself](https://makeself.io/)
- [python-build-standalone](https://github.com/indygreg/python-build-standalone)

Additional references:

- [Ansible Releases Explained](https://docs.ansible.com/ansible/latest/reference_appendices/release_and_maintenance.html)
- [Linux Support Explained](https://gregoryszorc.com/docs/python-build-standalone/20220227/running.html#linux)
- [Python Lifecycle](https://devguide.python.org/versions/#versions)
