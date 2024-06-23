#!/usr/bin/env sh
set -eu

### environment ###############################################################
WORKDIR=$(CDPATH="cd -- $(dirname -- "$0")" && pwd -P)
export WORKDIR

PATH_BIN="$WORKDIR/python/bin"
export PATH_BIN

PATH="$PATH_BIN:$PATH"
export PATH

### environment | python ######################################################
# ensure isolation
unset PYTHONPATH

# ensure python3 interpreter
if $(command -v sed) --version 2>&1 | grep -q 'GNU sed'; then
    find "${PATH_BIN}" -type f -exec sed -i '1s|^#!.*|#!'"$PATH_BIN"'/python3|' {} \;
else
    find "${PATH_BIN}" -type f -exec sed -i '' '1s|^#!.*|#!'"$PATH_BIN"'/python3|' {} \;
fi

### environment | python pip ##################################################
PIP_REQUIREMENTS="${PIP_REQUIREMENTS:-}"
if [ -n "$PIP_REQUIREMENTS" ]; then
    # shellcheck disable=SC2086
    "$PATH_BIN/python3" -m pip install --no-cache-dir $PIP_REQUIREMENTS
fi

### environment | ansible #####################################################
ANSIBLE_HOME="${ANSIBLE_HOME:-$WORKDIR/.ansible}"
export ANSIBLE_HOME
mkdir -p "$ANSIBLE_HOME"

if [ -n "${ANSIBLE_ROLES_PATH:-}" ]; then
    ANSIBLE_ROLES_PATH="$ANSIBLE_HOME/roles:$ANSIBLE_ROLES_PATH"
else
    ANSIBLE_ROLES_PATH="$ANSIBLE_HOME/roles"
fi
mkdir -p "$ANSIBLE_HOME/roles"
export ANSIBLE_ROLES_PATH

if [ -n "${ANSIBLE_COLLECTIONS_PATH:-}" ]; then
    ANSIBLE_COLLECTIONS_PATH="$ANSIBLE_HOME/collections:$ANSIBLE_COLLECTIONS_PATH"
else
    ANSIBLE_COLLECTIONS_PATH="$ANSIBLE_HOME/collections"
fi
mkdir -p "$ANSIBLE_HOME/collections"
export ANSIBLE_COLLECTIONS_PATH

# TODO: handle locales
# export LC_ALL=C.UTF-8

### assert | ansible galaxy compatibility ####################################
assert_ansible_galaxy() {
    # ansible galaxy supports ansible-core 2.13.9+ (ansible 6.0.0+)
    version=$("$PATH_BIN/python3" -m pip freeze | grep 'ansible-core' | awk -F'==' '{print $2}')

    version_major=$(echo "$version" | awk -F. '{print $1}')
    version_minor=$(echo "$version" | awk -F. '{print $2}')
    version_patch=$(echo "$version" | awk -F. '{print $3}')

    if { [ "$version_major" -lt 2 ]; } || \
       { [ "$version_major" -eq 2 ] && [ "$version_minor" -lt 13 ]; } || \
       { [ "$version_major" -eq 2 ] && [ "$version_minor" -eq 13 ] && [ "$version_patch" -lt 9 ]; }
    then
        echo "ERROR: ansible-core version $version is not supported"
        exit 6
    fi
}

### function | playbook #######################################################
playbook() {
    workspace=$1
    workspace_playbook="${2:-playbook.yml}"

    cd "$workspace" > /dev/null || exit 1
    # change directory if there is only one sub-directory in the workspace
    if { [ "$(find . -maxdepth 1 -type f | wc -l)" -eq 0 ]; } && \
       { [ "$(find . -maxdepth 1 -type d | wc -l)" -eq 2 ]; }
    then
        subdir=$(find . -maxdepth 1 -type d -not -name .)
        cd - > /dev/null || exit 1
        workspace="$workspace/$subdir"
        cd "$workspace" > /dev/null || exit 1
    fi

    ANSIBLE_PLAYBOOK_DIR=$(dirname "$workspace/$workspace_playbook")
    export ANSIBLE_PLAYBOOK_DIR

    # workspace: dotenv
    if [ -f .env ]; then
        while IFS= read -r line || [ -n "$line" ]; do
            case "$line" in
                "#"*) continue ;;
                "") continue ;;
                *)
                    var=${line%%=*}
                    eval "export ${var}=\${${var}:-${line#*=}}"
                    ;;
            esac
        done < .env
    fi

    # workspace: pip requirements
    if [ -f requirements.txt ]; then
        "$PATH_BIN/python3" -m pip install --no-cache-dir -r requirements.txt
    fi

    # workspace: ansible playbook
    if [ ! -f "$workspace_playbook" ]; then
        echo "ERROR: playbook not found: $workspace_playbook"
        exit 1
    fi

    # workspace: ansible roles
    if [ -d "$workspace/roles" ]; then
        export ANSIBLE_ROLES_PATH="$workspace/roles:$ANSIBLE_ROLES_PATH"
    fi

    # workspace: ansible collections
    if [ -d "$workspace/collections" ]; then
        export ANSIBLE_COLLECTIONS_PATH="$workspace/collections:$ANSIBLE_COLLECTIONS_PATH"
    fi

    # workspace: ansible galaxy
    if [ -f requirements.yml ]; then
        "$PATH_BIN/ansible-galaxy" install -r requirements.yml
    fi

    # workspace: ansible inventory
    if [ -z "${ANSIBLE_INVENTORY:-}" ]; then
        if [ -f "$workspace/hosts" ]; then
            export ANSIBLE_INVENTORY="$workspace/hosts"
        elif [ -f "$workspace/hosts.yml" ]; then
            export ANSIBLE_INVENTORY="$workspace/hosts.yml"
        fi
    elif [ -f "$ANSIBLE_INVENTORY" ]; then
        export ANSIBLE_INVENTORY
    elif [ -f "$USER_PWD/$ANSIBLE_INVENTORY" ]; then
        export ANSIBLE_INVENTORY="$USER_PWD/$ANSIBLE_INVENTORY"
    fi

    # workspace: ansible inventory (localhost)
    if [ ! -f host_vars/localhost.yml ]; then
        mkdir -p host_vars
        touch host_vars/localhost.yml
    fi
    if ! grep -qE 'ansible_python_interpreter' host_vars/localhost.yml; then
        echo "ansible_python_interpreter: \"$PATH_BIN/python3 -B\"" >> host_vars/localhost.yml
    fi

    # workspace: execute
    "$PATH_BIN/ansible-playbook" "$workspace_playbook"
    rc=$?

    cd - > /dev/null || exit 1
    return $rc
}

### cli | main ###########################################################
main() {
    playbook="$1"
    playbook_version="${2:-}"

    location=""
    location_type=""

    workspace_playbook="playbook.yml"

    # use case 1.1: directory path (relative path to directory with playbook.yml, e.g "myplaybook")
    if [ -d "$playbook" ] || [ -d "$USER_PWD/$playbook" ]; then
        if echo "$playbook" | grep -qE '^/'; then
            location="$playbook"
        else
            location="$USER_PWD/$playbook"
        fi
        location_type="directory"

    # use case 1.2: file path
    elif [ -f "$playbook" ] || [ -f "$USER_PWD/$playbook" ]; then
        if echo "$playbook" | grep -qE '^/'; then
            location="$playbook"
        else
            location="$USER_PWD/$playbook"
        fi

        # use case 1.2.1: file yaml relative path (relative path to *.yml playbook, e.g "myplaybook/playbook.yml")
        if echo "$location" | grep -qE '\.ya?ml$'; then
            location="$(dirname "$location")"
            location_type="directory"

        # use case 1.2.2: file tarball relative path (relative path to *.tar.gz playbook, e.g "myplaybook.tar.gz")
        elif echo "$location" | grep -qE '\.tar\.gz$'; then
            location_type="tarball"

        else
            echo "Error: unsupported playbook file format '$location'"
            exit 4
        fi

    # use case 2.1: ansible galaxy role (e.g "username.rolename")
    elif echo "$playbook" | grep -qE '^[a-z0-9_]+\.[a-z0-9_]+$'; then
        location="$playbook"
        location_type="galaxy_role"

    # use case 2.2: ansible galaxy collection (e.g "username.collectionname.rolename")
    elif echo "$playbook" | grep -qE '^[a-z0-9_]+\.[a-z0-9_]+\.[a-z0-9_]+$'; then
        location="$playbook"
        location_type="galaxy_collection"

    # use case 3.1: http url (e.g "http://example.com/playbook.tar.gz")
    elif echo "$playbook" | grep -qE '^https?://'; then
        location="$playbook"

        # use case 3.1.1: http url playbook (e.g "http://example.com/playbook.yml")
        if echo "$location" | grep -qE '\.ya?ml$'; then
            location_type="http_playbook"

        # use case 3.1.2: http url tarball (e.g "http://example.com/playbook.tar.gz")
        elif echo "$location" | grep -qE '\.tar\.gz$'; then
            location_type="http_tarball"
        fi

    # use case 4.1: github repository (e.g "github.com/username/repo")
    elif echo "$playbook" | grep -qE '^github.com/.+/.+$'; then
        location="$playbook"
        location_type="github"

    # use case 5.1: actions (@)
    elif echo "$playbook" | grep -qE '^@'; then
        location="$(echo "$playbook" | awk -F@ '{print $2}')"
        location_type="github"

        # use case 5.1.1: @owner/playbook ~ github.com/<owner>/ansible-collection-actions//playbooks/<playbook>.yml
        repo_owner="$(echo "$location" | awk -F/ '{print $1}')"
        repo_playbook="$(echo "$location" | awk -F/ '{print $2}')"

        # use case 5.1.2: @playbook ~ github.com/getansible/ansible-collection-actions//playbooks/<playbook>.yml
        if [ -z "$repo_playbook" ]; then
            repo_playbook="$repo_owner"
            repo_owner="getansible"
        fi

        location="github.com/$repo_owner/ansible-collection-actions"
        workspace_playbook="playbooks/$repo_playbook.yml"

    else
        echo "Error: invalid playbook location '$playbook'"
        exit 1
    fi

    workspace="${WORKDIR}/workspace"
    mkdir -p "$workspace"

    case "$location_type" in
        directory)
            workspace="$location"
            ;;
        tarball)
            tar -C "$workspace" -xzf "$location"
            ;;
        galaxy_role|galaxy_collection)
            assert_ansible_galaxy

            if [ "$location_type" = "galaxy_role" ]; then
                galaxy_name="$location"
            else
                galaxy_name="$(echo "$location" | cut -d. -f1,2)"
            fi

            if [ -n "$playbook_version" ]; then
                galaxy_version="==$playbook_version"
            else
                galaxy_version=""
            fi

            if [ "$location_type" = "galaxy_role" ]; then
                "$PATH_BIN/ansible-galaxy" role install "$galaxy_name$galaxy_version"
            else
                "$PATH_BIN/ansible-galaxy" collection install "$galaxy_name$galaxy_version"
            fi
            cat <<EOF > "$workspace/playbook.yml"
---
- hosts: localhost
  connection: local
  gather_facts: true
  vars:
    ansible_python_interpreter: "{{ ansible_playbook_python }} -B"
  roles:
    - role: $location
EOF
            ;;
        http_tarball)
            tmpfile="$WORKDIR/playbook.tar.gz"
            curl -fsSL -o "$tmpfile" "$location"
            tar -C "$workspace" -xzf "$tmpfile"
            ;;
        http_playbook)
            tmpfile="$workspace/playbook.yml"
            curl -fsSL -o "$tmpfile" "$location"
            ;;
        github)
            tmpfile="$WORKDIR/playbook.tar.gz"
            if [ -n "$playbook_version" ]; then
                curl -fsSL -o "$tmpfile" "https://codeload.$location/tar.gz/$playbook_version"
            else
                curl -fsSL -o "$tmpfile" "https://codeload.$location/tar.gz/main"
            fi
            tar -C "$workspace" -xzf "$tmpfile"
            ;;
    esac

    playbook "$workspace" "$workspace_playbook"
}

### cli | usage ###############################################################
usage() {
    echo "Usage: getansible -- exec|ansible|ansible-* [args]"
}

### cli #######################################################################
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
        exec "$PATH_BIN/$command" "$@"
        ;;
    help|-h|--help)
        usage
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
