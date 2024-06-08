#!/usr/bin/env bash
set -x

SOURCEDIR=$(CDPATH="cd -- $(dirname -- "$0")" && pwd -P)
export SOURCEDIR

PLATFORM_OS=$(uname -s | tr '[:upper:]' '[:lower:]')
PLATFORM_ARCH=$(uname -m | tr '[:upper:]' '[:lower:]')
if [ "${PLATFORM_ARCH}" = "aarch64" ]; then
    PLATFORM_ARCH="arm64"
fi
if [ "${PLATFORM_ARCH}" = "x86_64" ]; then
    PLATFORM_ARCH="amd64"
fi

ANSIBLE_RELEASE="${ANSIBLE_RELEASE:-10.0}"
PYTHON_RELEASE="${PYTHON_RELEASE:-20240415}"
PYTHON_VERSION="${PYTHON_VERSION:-3.11.9}"

if [ "${PLATFORM_OS}" = "darwin" ]; then
    PYTHON_OS="apple-darwin"
elif [ "${PLATFORM_OS}" = "linux" ]; then
    PYTHON_OS="unknown-linux-gnu"
else
    echo "Unsupported OS: ${PLATFORM_OS}"
    exit 1
fi

if [ "${PLATFORM_ARCH}" = "amd64" ]; then
    PYTHON_ARCH="x86_64"
elif [ "${PLATFORM_ARCH}" = "arm64" ]; then
    PYTHON_ARCH="aarch64"
else
    echo "Unsupported architecture: ${PLATFORM_ARCH}"
    exit 1
fi

WORKDIR=$(mktemp -d)

pushd "${WORKDIR}"
PYTHON="cpython-${PYTHON_VERSION}+${PYTHON_RELEASE}-${PYTHON_ARCH}-${PYTHON_OS}-install_only.tar.gz"
curl -fsSLo "${PYTHON}" "https://github.com/indygreg/python-build-standalone/releases/download/${PYTHON_RELEASE}/${PYTHON}"
tar xzf "${PYTHON}"
rm -f "${PYTHON}"
popd

mkdir "${WORKDIR}/getansible"
mv "${WORKDIR}/python" "${WORKDIR}/getansible/python"

PYTHONBIN="${WORKDIR}/getansible/python/bin"
PYTHON="${PYTHONBIN}/python3"

"${PYTHON}" -m pip install --upgrade ansible~="${ANSIBLE_RELEASE}"
if [ "${PLATFORM_OS}" = "darwin" ]; then
    find "${PYTHONBIN}" -type f -exec sed -i '' '1s|^#!.*$|#!/usr/bin/env python3|' {} \;
else
    find "${PYTHONBIN}" -type f -exec sed -i '1s|^#!.*$|#!/usr/bin/env python3|' {} \;
fi

cp "${SOURCEDIR}/entrypoint.sh" "${WORKDIR}/getansible/entrypoint.sh"
chmod 0755 "${WORKDIR}/getansible/entrypoint.sh"
rm -r "${WORKDIR}/getansible/python/share/"
find "${WORKDIR}/getansible/python" -type d -name "__pycache__" -print | xargs rm -rf
find "${WORKDIR}/getansible/python" -type d -name "tests" -print | xargs rm -rf

"${SOURCEDIR}/bin/makeself.sh" \
    --header "${SOURCEDIR}/bin/makeself-header.sh" \
    --gzip --complevel 1 \
    --nomd5 --nocrc \
    --tar-format gnu \
    --tar-quietly \
    --tar-extra '--mtime=2024-01-01' \
    --packaging-date '2024-01-01T00:00:00Z' \
    "${WORKDIR}/getansible" \
    "${WORKDIR}/getansible.sh" \
    "Ansible ${ANSIBLE_RELEASE} (Python ${PYTHON_VERSION})" \
    ./entrypoint.sh

chmod 0755 "${WORKDIR}/getansible.sh"
mkdir -p "${SOURCEDIR}/dist"
cp "${WORKDIR}/getansible.sh" "${SOURCEDIR}/dist/getansible-${ANSIBLE_RELEASE}-${PLATFORM_OS}-${PLATFORM_ARCH}.sh"
