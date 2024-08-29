#!/usr/bin/env sh

workspace_open() {
    workspace=$1
    cd "$workspace" > /dev/null || exit 1

    # change directory if there is only one sub-directory in the workspace
    if { [ "$(find . -maxdepth 1 -type f | wc -l)" -eq 0 ]; } && \
       { [ "$(find . -maxdepth 1 -type d | wc -l)" -eq 2 ]; }
    then
        subdir=$(find . -maxdepth 1 -type d -not -name . )
        cd - > /dev/null || exit 1
        workspace="$workspace/$subdir"
        cd "$workspace" > /dev/null || exit 1
    fi
}

workspace_dotenv() {
    workspace=$1
    if [ -f "${workspace}/.env" ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                "#"*) continue ;;
                "") continue ;;
                *)
                    var=${line%%=*}
                    eval "export ${var}=\${${var}:-${line#*=}}"
                    ;;
            esac
        done < "${workspace}/.env"
    fi
}

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

workspace_clone_config() {
    workspace=$1
    config=$2

    if [ -f "$config" ]; then
        cp "$config" "$workspace/ansible.cfg"
    fi
}
