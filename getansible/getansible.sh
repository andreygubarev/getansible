#!/usr/bin/env bash

WORKDIR=$(CDPATH="cd -- $(dirname -- "$0")" && pwd -P)
export WORKDIR
export PATH="$WORKDIR/bin:$PATH"

cd "$USER_PWD" || exit 1

case "$1" in
    exec)
        shift
        exec "$@"
        ;;
    ansible|ansible-*)
        command=$1
        shift
        exec "$WORKDIR/bin/$command" "$@"
        ;;
    *)
        echo "Usage: getansible -- exec|ansible|ansible-* [args]"
        exit 1
        ;;
esac
