# `getansible.sh` - Ansible Installer (Portable)

## Getting Started

```bash
# execute without installing
curl -s https://getansible.sh/ | sh -s -- ansible-playbook playbook.yml

# install and execute
curl -s https://getansible.sh/ | sh
getansible.sh -- ansible-playbook playbook.yml
```

## Overview

`getansible.sh` is a shell script that contains a self-extracting archive of Ansible (including dependencies) and Python interpreter. It can be executed on any Linux machine without the need to install Ansible.

Supported Platforms:

- Linux with GLIBC 2.17+ on `amd64` and `arm64` architectures.

Features:

- ansible-core 2.16.6
- python 3.12.3

## Motivation

Using Ansible for provisioning and configuration management of cloud resources is a common practice, but it requires the installation of Ansible on the local machine.

Use case:

1. Need to create a new deployment on AWS EC2.
2. Setup Autoscaling Group for high availability and reliability.
3. Need to provision new instances with Ansible.

In this case, the new instance may not have Ansible installed, until it was baked into AMI (if so then you don't have a problem this script solves).

### Why not install Ansible using package manager?

- **Compatibility**: each OS has its own package manager, and the version of Ansible may not be the same.

- **Dependency**: installing Ansible may require additional packages, e.g. Python and Python packages.

- **Reliability**: package repositories may be down, or the package may be removed.

- **Reproducibility**: the version of Ansible may change over time, and the playbook may not work as expected, target EC2 may contain contain incompatible changes.

# Reference

The project is possible huge thanks to the following projects:

- [Ansible](https://www.ansible.com/)
- [Makeself](https://makeself.io/)
- [python-build-standalone](https://github.com/indygreg/python-build-standalone)
