#!/bin/sh

WORKDIR=$(CDPATH="cd -- $(dirname -- "$0")" && pwd -P)
export WORKDIR
export PATH=$WORKDIR/bin:$PATH

cd $USER_PWD

case "$1" in
    exec)
        shift
        exec $@
        ;;
    ansible|ansible-galaxy|ansible-playbook|ansible-*)
        command=$1
        shift
        exec $WORKDIR/bin/$command $@
        ;;
    *)
        echo "Usage: getansible -- exec|ansible|ansible-galaxy|ansible-playbook|ansible-* [args]"
        exit 1
        ;;
esac
