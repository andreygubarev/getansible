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

playbook() {
    playbook_url=$1

    tmpfile=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f $tmpfile" EXIT
    curl -fsSL -o "$tmpfile" "$playbook_url"

    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf $tmpdir" EXIT

    tar -xzf "$tmpfile" "$tmpdir"
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
    fi

    if [ -f playbook.yml ]; then
        "$WORKDIR"/bin/ansible-playbook playbook.yml
    fi

    popd > /dev/null || exit 1
}

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
        echo "Usage: getansible -- exec|ansible|ansible-* [args]"
        exit 0
        ;;
    *)
        playbook "$1"
        ;;
esac
