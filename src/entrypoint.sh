#!/usr/bin/env bash
set -euo pipefail

### environment ###############################################################
WORKDIR=$(CDPATH="cd -- $(dirname -- "$0")" && pwd -P)
export WORKDIR

PATH="$WORKDIR/bin:$PATH"
export PATH

### environment | python ######################################################
# ensure isolation
unset PYTHONPATH

# ensure python3 is available
sed -i "s|#!/usr/bin/env python3|#!$WORKDIR/bin/python3|" "$WORKDIR"/bin/ansible*

### environment | python pip ##################################################
PIP_REQUIREMENTS="${PIP_REQUIREMENTS:-}"
if [ -n "$PIP_REQUIREMENTS" ]; then
    # shellcheck disable=SC2086
    "$WORKDIR"/bin/pip3 install --no-cache-dir $PIP_REQUIREMENTS
fi

### environment | ansible #####################################################
export ANSIBLE_HOME="$WORKDIR/.ansible"
export LC_ALL=C.UTF-8
export LANG=C.UTF-8

### assert | ansible galaxy compatibility ####################################
assert_ansible_galaxy() {
    # ansible galaxy supports ansible-core 2.13.9+ (ansible 6.0.0+)
    version=$("${WORKDIR}"/bin/pip3 freeze | grep 'ansible-core' | awk -F'==' '{print $2}')

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
    playbook_dir=$1
    playbook_subdir=$2

    workdir="$playbook_dir"
    if [ -n "$playbook_subdir" ]; then
        workdir="$playbook_dir/$playbook_subdir"
    fi

    pushd "$workdir" > /dev/null || exit 1

    # if there is only one file in the playbook_dir and it is a directory, cd into it
    if [ "$(find . -maxdepth 1 -type f | wc -l)" -eq 0 ] && [ "$(find . -maxdepth 1 -type d | wc -l)" -eq 2 ]; then
        subdir=$(find . -maxdepth 1 -type d -not -name .)
        popd > /dev/null || exit 1
        pushd "$workdir/$subdir" > /dev/null || exit 1
    fi

    ANSIBLE_PLAYBOOK_DIR=$(pwd)
    export ANSIBLE_PLAYBOOK_DIR

    if [ ! -f playbook.yml ]; then
        echo "No playbook.yml found"
        exit 5
    fi

    if [ -f .env ]; then
        while IFS= read -r var || [[ -n "$var" ]]; do
            if [[ ! "$var" == "" ]] && [[ ! "$var" == \#* ]]; then
                var_name=${var%%=*}
                echo "$var_name"
                if ! declare -p "$var_name" > /dev/null 2>&1; then
                    export "${var?}"
                fi
            fi
        done < .env
    fi

    if [ -z "${ANSIBLE_INVENTORY:-}" ]; then
        tmphosts=$(mktemp)

        if [ -p /dev/stdin ]; then
            cat - > "$tmphosts"
        fi

        if [ -s "$tmphosts" ]; then
            if [ "$(head -n 1 "$tmphosts")" == "---" ]; then
                cp "$tmphosts" "$(pwd)/hosts.yml"
                ANSIBLE_INVENTORY="$(pwd)/hosts.yml"
            else
                cp "$tmphosts" "$(pwd)/hosts"
                ANSIBLE_INVENTORY="$(pwd)/hosts"
            fi
        elif [ -f hosts ]; then
            ANSIBLE_INVENTORY="$(pwd)/hosts"
        elif [ -f hosts.yml ]; then
            ANSIBLE_INVENTORY="$(pwd)/hosts.yml"
        fi

        export ANSIBLE_INVENTORY
        rm -rf "$tmphosts"
    fi

    if [ ! -f host_vars/localhost.yml ]; then
        mkdir -p host_vars
        touch host_vars/localhost.yml
    fi
    if ! grep -q 'ansible_python_interpreter' host_vars/localhost.yml; then
        echo "ansible_python_interpreter: $WORKDIR/bin/python3" >> host_vars/localhost.yml
    fi

    if [ -f requirements.txt ]; then
        "$WORKDIR"/bin/pip3 install --no-cache-dir -r requirements.txt
    fi

    if [ -z "${ANSIBLE_ROLES_PATH:-}" ]; then
        export ANSIBLE_ROLES_PATH="$ANSIBLE_PLAYBOOK_DIR/roles"
    fi
    mkdir -p "$ANSIBLE_ROLES_PATH"

    if [ -z "${ANSIBLE_COLLECTIONS_PATH:-}" ]; then
        export ANSIBLE_COLLECTIONS_PATH="$ANSIBLE_PLAYBOOK_DIR/collections"
    fi
    mkdir -p "$ANSIBLE_COLLECTIONS_PATH"

    if [ -f requirements.yml ]; then
        "$WORKDIR"/bin/ansible-galaxy install -r requirements.yml
        echo $?
    fi

    "$WORKDIR"/bin/ansible-playbook playbook.yml
    rc=$?

    popd > /dev/null || exit 1
    rm -rf "$playbook_dir"
    return $rc
}

### cli | main ###########################################################
main() {
    playbook="$1"
    playbook_version="${2:-}"

    location=""
    location_type=""

    # use case 1.1: directory path (relative path to directory with playbook.yml, e.g "myplaybook")
    if [ -d "$playbook" ] || [ -d "$USER_PWD/$playbook" ]; then
        if echo "$playbook" | grep -q '^/'; then
            location="$playbook"
        else
            location="$USER_PWD/$playbook"
        fi
        location_type="directory"

    # use case 1.2: file path
    elif [ -f "$playbook" ] || [ -f "$USER_PWD/$playbook" ]; then
        if echo "$playbook" | grep -q '^/'; then
            location="$playbook"
        else
            location="$USER_PWD/$playbook"
        fi

        # use case 1.2.1: file yaml relative path (relative path to *.yml playbook, e.g "myplaybook/playbook.yml")
        if echo "$location" | grep -q '\.ya?ml$'; then
            location="$(dirname "$location")"
            location_type="directory"

        # use case 1.2.2: file tarball relative path (relative path to *.tar.gz playbook, e.g "myplaybook.tar.gz")
        elif echo "$location" | grep -q '\.tar\.gz$'; then
            location="$location"
            location_type="tarball"

        else
            echo "Error: unsupported playbook file format '$location'"
            exit 4
        fi

    # use case 2.1: ansible galaxy role (e.g "username.rolename")
    elif echo "$playbook" | grep -q '^[a-z0-9_]+\.[a-z0-9_]+$'; then
        location="$playbook"
        location_type="galaxy_role"

    # use case 2.2: ansible galaxy collection (e.g "username.collectionname.rolename")
    elif echo "$playbook" | grep -q '^[a-z0-9_]+\.[a-z0-9_]+\.[a-z0-9_]+$'; then
        location="$playbook"
        location_type="galaxy_collection"

    # use case 3.1: http url (e.g "http://example.com/playbook.tar.gz")
    elif echo "$playbook" | grep -q '^https?://'; then
        location="$playbook"

        # use case 3.1.1: http url playbook (e.g "http://example.com/playbook.yml")
        if echo "$location" | grep -q '\.ya?ml$'; then
            location_type="http_playbook"

        # use case 3.1.2: http url tarball (e.g "http://example.com/playbook.tar.gz")
        elif echo "$location" | grep -q '\.tar\.gz$'; then
            location_type="http_tarball"
        fi

    # use case 4.1: github repository (e.g "github.com/username/repo")
    elif echo "$playbook" | grep -q '^github.com/.+/.+$'; then
        location="$playbook"
        location_type="github"

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

            if [ -n "$playbook_version" ]; then
                location_version="==$url_version"
            else
                location_version=""
            fi

            if [ "$location_type" = "galaxy_role" ]; then
                "$WORKDIR"/bin/ansible-galaxy role install "$location$location_version"
            else
                "$WORKDIR"/bin/ansible-galaxy collection install "$location$location_version"
            fi
            cat <<EOF > "$workspace/playbook.yml"
---
- hosts: localhost
  connection: local
  gather_facts: true
  vars:
    ansible_python_interpreter: "{{ ansible_playbook_python }}"
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

    playbook "$workspace"
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
