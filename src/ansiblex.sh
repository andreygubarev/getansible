#!/bin/sh

WORKDIR=$(CDPATH="cd -- $(dirname -- "$0")" && pwd -P)
export WORKDIR

case "$1" in
    ansible)
        shift
        $WORKDIR/bin/python3 -m ansible.cli.adhoc $@
        ;;
    ansible-playbook)
        shift
        $WORKDIR/bin/python3 -m ansible.cli.playbook $@
        ;;
    ansible-galaxy)
        shift
        $WORKDIR/bin/python3 -m ansible.cli.galaxy $@
        ;;
    ansible-vault)
        shift
        $WORKDIR/bin/python3 -m ansible.cli.vault $@
        ;;
    *)
        echo "Usage: ansiblex -- ansible|ansible-playbook|ansible-galaxy|ansible-vault [args]"
        exit 1
        ;;
esac
