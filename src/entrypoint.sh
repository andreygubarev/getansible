#!/usr/bin/env bash
set -euo pipefail

WORKDIR=$(CDPATH="cd -- $(dirname -- "$0")" && pwd -P)
export WORKDIR
export PATH="$WORKDIR/bin:$PATH"
sed -i "s|#!/usr/bin/env python3|#!$WORKDIR/bin/python3|" "$WORKDIR"/bin/ansible*

PYTHON_REQUIREMENTS="${PYTHON_REQUIREMENTS:-}"
if [ -n "$PYTHON_REQUIREMENTS" ]; then
    # shellcheck disable=SC2086
    "$WORKDIR"/bin/pip3 install --no-cache-dir $PYTHON_REQUIREMENTS
fi

cd "$USER_PWD" || exit 1

usage() {
    echo "Usage: getansible -- exec|ansible|ansible-* [args]"
}

main() {
    playbook_url=$1

    tmpfile=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f $tmpfile" EXIT

    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf $tmpdir" EXIT

    case "$playbook_url" in
        http://*|https://*)
            curl -fsSL -o "$tmpfile" "$playbook_url"
            ;;
        file://*)
            fname="${playbook_url#file://}"
            if [ -f "$fname" ]; then
                cp "$fname" "$tmpfile"
            elif [ -d "$fname" ]; then
                tar -C "$fname" -czf "$tmpfile" .
            else
                echo "Invalid playbook: $fname"
                exit 3
            fi
            ;;
        *)
            echo "Invalid playbook URL: $playbook_url"
            exit 3
            ;;
    esac

    ftype=$(file -b --mime-type "$tmpfile")
    case "$ftype" in
        application/gzip)
            tar -C "$tmpdir" -xzf "$tmpfile"
            ;;
        application/zip)
            unzip -d "$tmpdir" "$tmpfile"
            ;;
        text/plain)
            cp "$tmpfile" "$tmpdir/playbook.yml"
            ;;
        *)
            echo "Invalid playbook file type: $ftype"
            exit 4
            ;;
    esac

    pushd "$tmpdir" > /dev/null || exit 1

    if [ -f .env ]; then
        # shellcheck disable=SC1091
        . .env
    fi

    if [ -f requirements.txt ]; then
        "$WORKDIR"/bin/pip3 install --no-cache-dir -r requirements.txt
    fi

    if [ -f requirements.yml ]; then
        "$WORKDIR"/bin/ansible-galaxy install -r requirements.yml
        echo $?
    fi

    if [ -d roles ]; then
        export ANSIBLE_ROLES_PATH="$tmpdir/roles"
    fi

    if [ -f playbook.yml ]; then
        "$WORKDIR"/bin/ansible-playbook playbook.yml
    else
        echo "No playbook.yml found"
        exit 5
    fi

    popd > /dev/null || exit 1
}

if [ $# -eq 0 ]; then
    usage
    exit 2
fi

case "${1:-}" in
    exec)
        shift
        exec "$@"
        ;;
    ansible|ansible-*)
        command=$1
        shift
        exec "$WORKDIR/bin/$command" "$@"
        ;;
    help|-h|--help)
        usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
