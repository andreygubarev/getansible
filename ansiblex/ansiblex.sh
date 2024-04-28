#!/bin/sh

WORKDIR=$(CDPATH="cd -- $(dirname -- "$0")" && pwd -P)
export WORKDIR

export PATH=$WORKDIR/bin:$PATH

case "$1" in
    exec)
        shift
        source $WORKDIR/bin/activate
        exec $@
        ;;
    ansible)
        shift
        python3 -m ansible.cli.adhoc $@
        ;;
    ansible-playbook)
        shift
        python3 -m ansible.cli.playbook $@
        ;;
    ansible-galaxy)
        shift
        python3 -m ansible.cli.galaxy $@
        ;;
    ansible-vault)
        shift
        python3 -m ansible.cli.vault $@
        ;;
    *)
        echo "Usage: ansiblex -- ansible|ansible-playbook|ansible-galaxy|ansible-vault [args]"
        exit 1
        ;;
esac
