#!/usr/bin/env sh
set -eu

### variables #################################################################
GETANSIBLE_OS="${GETANSIBLE_OS:-}"
GETANSIBLE_ARCH="${GETANSIBLE_ARCH:-}"
GETANSIBLE_PATH="${GETANSIBLE_PATH:-/usr/local/bin/getansible.sh}"

ANSIBLE_RELEASE="${ANSIBLE_RELEASE:-10.0}"

### pre-requisites ############################################################
if ! command -v curl > /dev/null; then
    echo "missing dependency: curl"
    exit 1
fi

if ! command -v sed > /dev/null; then
    echo "missing dependency: sed"
    exit 1
fi

if ! command -v grep > /dev/null; then
    echo "missing dependency: grep"
    exit 1
fi

if ! command -v uname > /dev/null; then
    echo "missing dependency: uname"
    exit 1
fi

if [ -z "$GETANSIBLE_ARCH" ]; then
    GETANSIBLE_ARCH=$(uname -m)
fi
case $GETANSIBLE_ARCH in
    x86_64)
        GETANSIBLE_ARCH="amd64"
        ;;
    aarch64|arm64)
        GETANSIBLE_ARCH="arm64"
        ;;
    *)
        echo "unsupported architecture: $GETANSIBLE_ARCH"
        exit 1
        ;;
esac

if [ -z "$GETANSIBLE_OS" ]; then
    GETANSIBLE_OS=$(uname -s)
fi
case $GETANSIBLE_OS in
    Linux)
        GETANSIBLE_OS="linux"
        ;;
    Darwin)
        GETANSIBLE_OS="darwin"
        ;;
    *)
        echo "unsupported OS: $GETANSIBLE_OS"
        exit 1
        ;;
esac

### functions #################################################################
getansible_install() {
    ansible_release="$1"
    getansible_path="$2"
    link_option="$3"

    if [ -e "$getansible_path" ]; then
        if [ ! -w "$getansible_path" ]; then
            echo "path is not writable: $getansible_path"
            exit 1
        fi
    elif [ ! -w "$(dirname "$getansible_path")" ]; then
        echo "path is not writable: $(dirname "$getansible_path")"
        exit 1
    fi

    GITHUB_OWNER="andreygubarev"
    GITHUB_REPO="getansible"
    GITHUB_RELEASE=$(curl --connect-timeout 10 -s "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    GITHUB_ARTIFACT="getansible-$ansible_release-$GETANSIBLE_OS-$GETANSIBLE_ARCH.sh"
    GITHUB_DOWNLOAD_URL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$GITHUB_RELEASE/$GITHUB_ARTIFACT"

    getansible_tempdir=$(mktemp -d)
    curl --connect-timeout 10 -sLo "$getansible_tempdir/$GITHUB_ARTIFACT" "$GITHUB_DOWNLOAD_URL"

    if command -v sha512sum > /dev/null; then
        SHA512SUMS=$(mktemp)
        curl --connect-timeout 10 -sLo "$SHA512SUMS" "https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$GITHUB_RELEASE/SHA512SUMS"
        cd "$getansible_tempdir" > /dev/null
        sha512sum -c "$SHA512SUMS" --ignore-missing
        cd - > /dev/null
        rm -f "$SHA512SUMS"
    fi

    mv "$getansible_tempdir/$GITHUB_ARTIFACT" "$getansible_path"
    chmod +x "$getansible_path"
    rm -rf "$getansible_tempdir"

    if [ "$link_option" = "true" ]; then
        getansible_link "$getansible_path"
    fi
}

getansible_link() {
    getansible_path="$1"

    cat > /usr/local/bin/ansible <<EOF
#!/usr/bin/env bash
exec "$getansible_path" -- ansible "\$@"
EOF
    chmod +x /usr/local/bin/ansible

    cat > /usr/local/bin/ansible-galaxy <<EOF
#!/usr/bin/env bash
exec "$getansible_path" -- ansible-galaxy "\$@"
EOF
    chmod +x /usr/local/bin/ansible-galaxy

    cat > /usr/local/bin/ansible-playbook <<EOF
#!/usr/bin/env bash
exec "$getansible_path" -- ansible-playbook "\$@"
EOF
    chmod +x /usr/local/bin/ansible-playbook

}

getansible_uninstall() {
    getansible_path="$1"
    rm -f "$getansible_path"
}

getansible_help() {
    echo "Usage: $0 [install]"
}

getansible() {
    tmpdir="$(mktemp -d)"

    getansible_install "$ANSIBLE_RELEASE" "$tmpdir/getansible.sh" "false"
    "$tmpdir/getansible.sh" -- "$@"
    rc=$?

    rm -rf "$tmpdir"
    return $rc
}

### main ######################################################################
if [ "$#" -eq 0 ]; then
    getansible_install "$ANSIBLE_RELEASE" "/usr/local/bin/getansible.sh" "false"
    exit 0
fi

case ${1:-} in
    install)
        shift
        link_option="false"
        for arg in "$@"; do
            case $arg in
                --link|-l)
                    link_option="true"
                    ;;
                --short)
                    GETANSIBLE_PATH="/usr/local/bin/gan.sh"
                    ;;
                *)
                    ;;
            esac
        done
        getansible_install "$ANSIBLE_RELEASE" "$GETANSIBLE_PATH" "$link_option"
        ;;
    uninstall)
        getansible_uninstall "$ANSIBLE_RELEASE" "$GETANSIBLE_PATH"
        ;;
    help|--help|-h)
        getansible_help
        ;;
    *)
        getansible "${@}"
        ;;
esac
