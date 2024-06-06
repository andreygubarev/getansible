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
assert_compat_galaxy() {
    # ansible galaxy supports ansible-core 2.13.9+ (ansible 6.0.0+)
    version=$("${WORKDIR}"/bin/pip3 freeze | grep 'ansible-core' | cut -d= -f3)
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

### function | usage ##########################################################
usage() {
    echo "Usage: getansible -- exec|ansible|ansible-* [args]"
}

### function | main ###########################################################
main() {
    url=$1
    if echo "$url" | grep -q '#'; then
        url_fragment=$(echo "$url" | cut -d'#' -f2)
    else
        url_fragment=""
    fi
    if [ -n "$url_fragment" ]; then
        url=$(echo "$url" | cut -d'#' -f1)
    fi

    # handler: ==1.0.0
    if echo "$url" | grep -q '=='; then
        url_version=$(echo "$url" | awk -F'==' '{print $2}')
        if [ -n "$url_version" ]; then
            url=$(echo "$url" | awk -F'==' '{print $1}')
        fi
    else
        url_version=""
    fi

    url_proto=$(echo "$url" | cut -d':' -f1)
    # url_host=$(echo "$url" | cut -d':' -f2 | cut -c3-)
    # url_path=$(echo "$url_host" | cut -d'/' -f2-)
    # url_host=$(echo "$url_host" | cut -d'/' -f1)

    tmpfile=$(mktemp)
    case "$url_proto" in
        http|https)
            curl -fsSL -o "$tmpfile" "$url"
            ;;
        file)
            fname="${url#file://}"
            if [ -f "$fname" ]; then
                cp "$fname" "$tmpfile"
            elif [ -d "$fname" ]; then
                tar -C "$fname" -czf "$tmpfile" .
            else
                echo "Invalid playbook: $fname"
                exit 3
            fi
            ;;
        galaxy)
            assert_compat_galaxy

            galaxy_dir=$(mktemp -d)
            galaxy_name="${url#galaxy://}"

            if [ -n "$url_version" ]; then
                galaxy_version="==$url_version"
            else
                galaxy_version=""
            fi

            if [ "$(echo "$galaxy_name" | tr -cd '.' | wc -c)" -eq 2 ]; then
                collection_name=$(echo "$galaxy_name" | cut -d. -f1-2)
                "$WORKDIR"/bin/ansible-galaxy collection install -p "$galaxy_dir/collections" "$collection_name$galaxy_version"
            else
                mkdir -p "$galaxy_dir/roles"
                "$WORKDIR"/bin/ansible-galaxy role install -p "$galaxy_dir/roles" "$galaxy_name$galaxy_version"
            fi

            cat <<EOF > "$galaxy_dir/playbook.yml"
---
- hosts: localhost
  connection: local
  gather_facts: true
  vars:
    ansible_python_interpreter: "{{ ansible_playbook_python }}"
  roles:
    - role: $galaxy_name
EOF
            pushd "$galaxy_dir" > /dev/null || exit 1
            tar -czf "$tmpfile" .
            popd > /dev/null || exit 1

            rm -rf "$galaxy_dir"
            ;;
        *)
            echo "Invalid URL: $url"
            exit 3
            ;;
    esac

    if command -v file > /dev/null; then
        ftype=$(file --brief --mime-type "$tmpfile")
    else
        case "$url_proto" in
            http|https)
                case "$url" in
                    *.tar.gz)
                        ftype="application/gzip"
                        ;;
                    *.zip)
                        ftype="application/zip"
                        ;;
                    *.yml|*.yaml)
                        ftype="text/plain"
                        ;;
                    *)
                        echo "Invalid playbook file: $url"
                        exit 4
                        ;;
                esac
                ;;
            file)
                fname="${url#file://}"
                if [ -f "$fname" ]; then
                    case "$fname" in
                        *.tar.gz)
                            ftype="application/gzip"
                            ;;
                        *.zip)
                            ftype="application/zip"
                            ;;
                        *.yml|*.yaml)
                            ftype="text/plain"
                            ;;
                        *)
                            echo "Invalid playbook file: $fname"
                            exit 4
                            ;;
                    esac
                elif [ -d "$fname" ]; then
                    ftype="application/gzip"
                fi
                ;;
            galaxy)
                ftype="application/gzip"
                ;;
            *)
                echo "Invalid playbook URL: $url"
                exit 3
                ;;
        esac
    fi

    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

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
    rm -f "$tmpfile"

    if [ -n "$url_fragment" ]; then
        if [ -d "$tmpdir/$url_fragment" ]; then
            subdir=$url_fragment
        else
            subdir=""
            echo "Invalid subdirectory: $url_fragment"
            exit 4
        fi
    else
        subdir=""
    fi

    playbook "$tmpdir" "$subdir"
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

### command line interface ####################################################
cd "$USER_PWD" || exit 1

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
