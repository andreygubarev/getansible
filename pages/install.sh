#!/usr/bin/env bash
set -eu

### variables #################################################################
GETANSIBLE_ARCH="${GETANSIBLE_ARCH:-}"
GETANSIBLE_PATH="${GETANSIBLE_PATH:-/usr/local/bin/getansible.sh}"

ANSIBLE_RELEASE="${ANSIBLE_RELEASE:-9.0}"

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

if [ "$(uname)" != "Linux" ]; then
    echo "unsupported operating system: $(uname)"
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

### functions #################################################################
getansible_install() {
    local ansible_release=$1
    local getansible_path=$2
    local link_option="$3"

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
    GITHUB_RELEASE=$(curl -s "https://api.github.com/repos/$GITHUB_OWNER/$GITHUB_REPO/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    GITHUB_ARTIFACT="getansible-$ansible_release-$GETANSIBLE_ARCH.sh"
    GITHUB_DOWNLOAD_URL="https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$GITHUB_RELEASE/$GITHUB_ARTIFACT"

    SHA512SUMS=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f $SHA512SUMS" EXIT
    curl -sLo "$SHA512SUMS" "https://github.com/$GITHUB_OWNER/$GITHUB_REPO/releases/download/$GITHUB_RELEASE/SHA512SUMS"

    getansible_tempdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf $getansible_tempdir" EXIT
    curl -sL "$GITHUB_DOWNLOAD_URL" -o "$getansible_tempdir/$GITHUB_ARTIFACT"

    pushd "$getansible_tempdir" > /dev/null
    sha512sum -c "$SHA512SUMS" --ignore-missing
    popd > /dev/null

    mv "$getansible_tempdir/$GITHUB_ARTIFACT" "$getansible_path"
    chmod +x "$getansible_path"

    if [ "$link_option" = "true" ]; then
        getansible_link "$getansible_path"
    fi
}

getansible_link() {
    local getansible_path=$1

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
    local getansible_path=$1

    rm -f "$getansible_path"
}

getansible_help() {
    echo "Usage: $0 [install]"
}

getansible_ansible() {
    tmpdir="$(mktemp -d)"

    # shellcheck disable=SC2064
    trap "rm -rf $tmpdir" EXIT

    getansible_install "$ANSIBLE_RELEASE" "$tmpdir/getansible.sh" "false"
    "$tmpdir/getansible.sh" -- "$@"
}

### main ######################################################################
case ${1:-} in
    ansible|ansible-galaxy|ansible-playbook|ansible-*)
        getansible_ansible "${@}"
        ;;
    install)
        shift
        link_option="false"
        for arg in "$@"; do
            case $arg in
                --link|-l)
                    link_option="true"
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
        getansible_install "$ANSIBLE_RELEASE" "$GETANSIBLE_PATH" "false"
        ;;
esac
