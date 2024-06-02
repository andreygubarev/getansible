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

assert_galaxy_support() {
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

usage() {
    echo "Usage: getansible -- exec|ansible|ansible-* [args]"
}

main() {
    playbook_url=$1

    tmpfile=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f $tmpfile" EXIT

    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf $tmpdir" EXIT

    case "$playbook_url" in
        http://*|https://*)
            curl -fsSL -o "$tmpfile" "$playbook_url"
            ;;
        file://*)
            fname="${playbook_url#file://}"
            if [ -f "$fname" ]; then
                cp "$fname" "$tmpfile"
            elif [ -d "$fname" ]; then
                tar -C "$fname" -czf "$tmpfile" .
            else
                echo "Invalid playbook: $fname"
                exit 3
            fi
            ;;
        galaxy://*)
            assert_galaxy_support

            role_name="${playbook_url#galaxy://}"
            roles_dir="$tmpdir/roles"
            mkdir -p "$roles_dir"

            if [ "$(echo "$role_name" | tr -cd '.' | wc -c)" -eq 2 ]; then
                collection_name=$(echo "$role_name" | cut -d. -f1-2)
                "$WORKDIR"/bin/ansible-galaxy collection install "$collection_name"
            else
                "$WORKDIR"/bin/ansible-galaxy role install "$role_name" -p "$roles_dir"
            fi

            cat <<EOF > "$tmpfile"
---
- hosts: localhost
  connection: local
  gather_facts: true
  vars:
    ansible_python_interpreter: "{{ ansible_playbook_python }}"
  roles:
    - role: $role_name
EOF
            ;;
        *)
            echo "Invalid playbook URL: $playbook_url"
            exit 3
            ;;
    esac

    if command -v file > /dev/null; then
        ftype=$(file --brief --mime-type "$tmpfile")
    else
        case "$playbook_url" in
            http://*|https://*)
                case "$playbook_url" in
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
                        echo "Invalid playbook file: $playbook_url"
                        exit 4
                        ;;
                esac
                ;;
            file://*)
                fname="${playbook_url#file://}"
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
            galaxy://*)
                ftype="text/plain"
                ;;
            *)
                echo "Invalid playbook URL: $playbook_url"
                exit 3
                ;;
        esac
    fi

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

    playbook "$tmpdir"
}

playbook() {
    playbook_dir=$1

    pushd "$playbook_dir" > /dev/null || exit 1
    # if there is only one file in the playbook_dir and it is a directory, cd into it
    if [ "$(find . -maxdepth 1 -type f | wc -l)" -eq 0 ] && [ "$(find . -maxdepth 1 -type d | wc -l)" -eq 2 ]; then
        subdir=$(find . -maxdepth 1 -type d -not -name .)
        popd > /dev/null || exit 1
        pushd "$playbook_dir/$subdir" > /dev/null || exit 1
    fi

    if [ ! -f playbook.yml ]; then
        echo "No playbook.yml found"
        exit 5
    fi

    if [ -z "${ANSIBLE_INVENTORY:-}" ]; then
        inventory=$(mktemp -d)
        # shellcheck disable=SC2064
        trap "rm -rf $inventory" EXIT

        while IFS= read -r line; do
            echo -e "$line" >> "$inventory/hosts"
        done

        if [ -s "$inventory/hosts" ]; then
            if [ "$(head -n 1 "$inventory/hosts")" == "---" ]; then
                mv "$inventory/hosts" "$inventory/hosts.yml"
                ANSIBLE_INVENTORY="$inventory/hosts.yml"
            else
                ANSIBLE_INVENTORY="$inventory/hosts"
            fi
        elif [ -f hosts ]; then
            ANSIBLE_INVENTORY="$(pwd)/hosts"
        elif [ -f hosts.yml ]; then
            ANSIBLE_INVENTORY="$(pwd)/hosts.yml"
        fi
        export ANSIBLE_INVENTORY
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

    if [ -f requirements.txt ]; then
        "$WORKDIR"/bin/pip3 install --no-cache-dir -r requirements.txt
    fi

    if [ -f requirements.yml ]; then
        "$WORKDIR"/bin/ansible-galaxy install -r requirements.yml
        echo $?
    fi

    if [ -d roles ]; then
        export ANSIBLE_ROLES_PATH="$playbook_dir/roles"
    fi

    if [ -d collections ]; then
        export ANSIBLE_COLLECTIONS_PATH="$playbook_dir/collections"
    fi

    "$WORKDIR"/bin/ansible-playbook playbook.yml
    popd > /dev/null || exit 1
}

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
