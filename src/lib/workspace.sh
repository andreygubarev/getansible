#!/usr/bin/env sh

workspace_clone_inventory() {
    workspace=$1
    inventory=$2

    if head -n 1 "$inventory" | grep -qE '^---'; then
        cp "$inventory" "$workspace/hosts.yml"
        echo "$workspace/hosts.yml"
    else
        cp "$inventory" "$workspace/hosts"
        echo "$workspace/hosts"
    fi

    if [ -d "$(dirname "$inventory")/group_vars" ]; then
        cp -r "$(dirname "$inventory")/group_vars" "$workspace"
    fi

    if [ -d "$(dirname "$inventory")/host_vars" ]; then
        cp -r "$(dirname "$inventory")/host_vars" "$workspace"
    fi
}
