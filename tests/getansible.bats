#!/usr/bin/env bash

setup() {
    bats_load_library bats-assert
    bats_load_library bats-file
    bats_load_library bats-support

    if [ -f /usr/local/bin/getansible.sh ]; then
        chmod +x /usr/local/bin/getansible.sh
    fi

    if [ -n "$TMPDIR" ]; then
      export TMPDIR="$TMPDIR/bats"
    else
      export TMPDIR="/tmp/bats"
    fi
    mkdir -p $TMPDIR
}

assert_teardown() {
    run test -z "$(ls -A $TMPDIR | grep -v 'bats-')"
    assert_success
}

# bats test_tags=T001,getansible
@test "T001: getansible.sh" {
    run getansible.sh
    assert_failure 2
    assert_output --partial "Usage: getansible"
    assert_teardown
}

# bats test_tags=T002,getansible
@test "T002: getansible.sh -- ansible" {
    run getansible.sh -- ansible --version
    assert_success
    assert_teardown
}

# bats test_tags=T003,getansible
@test "T003: getansible.sh -- ansible-galaxy" {
    run getansible.sh -- ansible-galaxy --version
    assert_success
    assert_teardown
}

# bats test_tags=T004,getansible
@test "T004: getansible.sh -- ansible-playbook" {
    run getansible.sh -- ansible-playbook --version
    assert_success
    assert_teardown
}

# bats test_tags=T005,python
@test "T005: getansible.sh -- exec pip" {
    run bash -c "PIP_REQUIREMENTS='boto3 botocore' getansible.sh -- exec pip freeze | grep boto3"
    assert_success
    assert_teardown
}

# bats test_tags=T006,getansible,galaxy
@test "T006: getansible.sh -- geerlingguy.apache" {
    run getansible.sh -- geerlingguy.apache
    assert_success
    assert_output --partial "geerlingguy.apache"
    assert_output --partial "failed=0"
    assert_teardown
}

# bats test_tags=T007,getansible,galaxy
@test "T007: getansible.sh -- andreygubarev.actions.ping" {
    run getansible.sh -- andreygubarev.actions.ping
    assert_success
    assert_output --partial "andreygubarev.actions.ping : Ping"
    assert_output --partial "failed=0"
    assert_teardown
}

# bats test_tags=T008,getansible,galaxy
@test "T008: getansible.sh -- andreygubarev.actions.ping==0.8.1" {
    run getansible.sh -- andreygubarev.actions.ping==0.8.1
    assert_success
    assert_output --partial "andreygubarev.actions.ping : Ping"
    assert_output --partial "failed=0"
    assert_teardown
}

# bats test_tags=T009,getansible,galaxy
@test "T009: getansible.sh -- andreygubarev.actions.ping==0.7.0" {
    run getansible.sh -- andreygubarev.actions.ping==0.7.0
    assert_failure  # version 0.7.0 does not have a ping role
    assert_teardown
}

# bats test_tags=T010,playbook
@test "T010: getansible.sh -- /opt/001-ping.tar.gz" {
    tar -czf /opt/001-ping.tar.gz -C /usr/src/bats/examples/001-ping .

    run getansible.sh -- /opt/001-ping.tar.gz
    assert_success
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T011,playbook
@test "T011: getansible.sh -- /opt/001-ping.tar.gz" {
    tar -czf /opt/001-ping.tar.gz -C /usr/src/bats/examples/001-ping .
    pushd /opt > /dev/null || exit 1

    run getansible.sh -- 001-ping.tar.gz
    assert_success
    assert_output --partial "ok=1"

    popd > /dev/null || exit 1
    assert_teardown
}

# bats test_tags=T012,playbook
@test "T012: getansible.sh -- /opt/002-requirements.tar.gz" {
    tar -czf /opt/002-requirements.tar.gz -C /usr/src/bats/examples/002-requirements .

    run getansible.sh -- /opt/002-requirements.tar.gz
    assert_success
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T013,playbook
@test "T013: getansible.sh -- /opt/003-roles.tar.gz" {
    tar -czf /opt/003-roles.tar.gz -C /usr/src/bats/examples/003-roles .

    run getansible.sh -- /opt/003-roles.tar.gz
    assert_success
    assert_output --partial '"msg": "getansible"'
    assert_output --partial "ok=2"
    assert_teardown
}

# bats test_tags=T014,playbook
@test "T014: getansible.sh -- /opt/004-subfolder.tar.gz" {
    tar -czf /opt/004-subfolder.tar.gz -C /usr/src/bats/examples/004-subfolder .

    run getansible.sh -- /opt/004-subfolder.tar.gz
    assert_success
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T015,playbook
@test "T015: getansible.sh -- /opt/005-dotenv.tar.gz" {
    tar -czf /opt/005-dotenv.tar.gz -C /usr/src/bats/examples/005-dotenv .

    run getansible.sh -- /opt/005-dotenv.tar.gz
    assert_success
    assert_output --partial "FOO=BAR"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T016,playbook
@test "T016: getansible.sh -- /opt/005-dotenv.tar.gz" {
    tar -czf /opt/005-dotenv.tar.gz -C /usr/src/bats/examples/005-dotenv .

    export FOO=BAZ
    run getansible.sh -- /opt/005-dotenv.tar.gz
    assert_success
    assert_output --partial "FOO=BAZ"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T017,playbook,inventory
@test "T017: getansible.sh -- /opt/006-inventory.tar.gz" {
    tar -czf /opt/006-inventory.tar.gz -C /usr/src/bats/examples/006-inventory .

    export ANSIBLE_INVENTORY=$(mktemp) && cat <<-EOF > ${ANSIBLE_INVENTORY}
---
ungrouped:
  hosts:
    localhost:
      foo: bar
EOF
    run getansible.sh -- /opt/006-inventory.tar.gz

    rm -f ${ANSIBLE_INVENTORY}
    unset ANSIBLE_INVENTORY

    assert_success
    assert_output --partial "foo=bar"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T018,playbook,inventory
@test "T018: getansible.sh -- /opt/006-inventory.tar.gz" {
    tar -czf /opt/006-inventory.tar.gz -C /usr/src/bats/examples/006-inventory .

    export ANSIBLE_INVENTORY=$(mktemp) && cat <<-EOF > ${ANSIBLE_INVENTORY}
localhost foo=bar
EOF
    run getansible.sh -- /opt/006-inventory.tar.gz

    rm -f ${ANSIBLE_INVENTORY}
    unset ANSIBLE_INVENTORY

    assert_success
    assert_output --partial "foo=bar"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T019,getansible,playbook
@test "T019: getansible.sh -- @andreygubarev/ping" {
    run getansible.sh -- @andreygubarev/ping
    assert_success
    assert_output --partial "ping : Ping"
    assert_teardown
}

# bats test_tags=T020,playbook,inventory
@test "T020: getansible.sh -- /opt/006-inventory.tar.gz" {
    tar -czf /opt/006-inventory.tar.gz -C /usr/src/bats/examples/006-inventory .

    export ANSIBLE_INVENTORY=inventory && cat <<-EOF > ${ANSIBLE_INVENTORY}
localhost foo=bar
EOF
    run getansible.sh -- /opt/006-inventory.tar.gz

    rm -f ${ANSIBLE_INVENTORY}
    unset ANSIBLE_INVENTORY

    assert_success
    assert_output --partial "foo=bar"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T021,playbook,inventory
@test "T021: getansible.sh -- /opt/006-inventory.tar.gz" {
    tar -czf /opt/006-inventory.tar.gz -C /usr/src/bats/examples/006-inventory .

    mkdir -p /etc/ansible
    cat <<EOF > /etc/ansible/hosts
---
ungrouped:
  hosts:
    localhost:
      foo: bar
EOF
    run getansible.sh -- /opt/006-inventory.tar.gz

    rm -f ${ANSIBLE_INVENTORY}
    unset ANSIBLE_INVENTORY

    assert_success
    assert_output --partial "foo=bar"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T022,getansible,galaxy
@test "T022: getansible.sh -- andreygubarev.actions.ping==0.9.3 --ping-message=ping" {
    run getansible.sh -- andreygubarev.actions.ping==0.9.3 --ping-message=ping
    assert_success
    assert_output --partial '"msg": "ping"'
    assert_teardown
}

# bats test_tags=T023,getansible,galaxy
@test "T023: getansible.sh -- andreygubarev.actions.ping==0.9.3" {
    run getansible.sh -- andreygubarev.actions.ping==0.9.3
    assert_success
    assert_output --partial '"msg": "pong"'
    assert_teardown
}

# bats test_tags=T024,getansible
@test "T024: getansible.sh -- /opt/008-vars" {
    tar -czf /opt/008-vars.tar.gz -C /usr/src/bats/examples/008-vars .

    run getansible.sh -- /opt/008-vars.tar.gz --var1 --var2=value2 --var3 value3 value4 --var5=value5 --var6= --var7=1 --var8=1.0 -var9 -var10=10 -a -b -c valueC valueD
    assert_success
    assert_teardown
}

# bats test_tags=T025,getansible
@test "T025: getansible.sh -- /opt/009-vars-command" {
    tar -czf /opt/009-vars-command.tar.gz -C /usr/src/bats/examples/009-vars-command .

    run getansible.sh -- /opt/009-vars-command.tar.gz install --var1 --var2=value2 --command=cmd
    assert_success
    assert_teardown

    run getansible.sh -- /opt/009-vars-command.tar.gz install cmd1 cmd2 --var1 --var2=value2 --command=cmd
    assert_success
    assert_teardown

    run getansible.sh -- /opt/009-vars-command.tar.gz cmd1
    assert_failure
    assert_teardown
}

# bats test_tags=T100,install
@test "T100: install.sh install" {
    run install.sh install
    assert_success
    assert_file_exist /usr/local/bin/getansible.sh
    assert_teardown
}

# bats test_tags=T101,install
@test "T101: install.sh install --link" {
    run install.sh install --link
    assert_success

    assert_file_exist /usr/local/bin/ansible
    assert_file_exist /usr/local/bin/ansible-galaxy
    assert_file_exist /usr/local/bin/ansible-playbook

    run ansible --version
    assert_success

    run ansible-galaxy --version
    assert_success

    run ansible-playbook --version
    assert_success

    assert_teardown
}

# bats test_tags=T102,install
@test "T102: install.sh /opt/001-ping.tar.gz" {
    tar -czf /opt/001-ping.tar.gz -C /usr/src/bats/examples/001-ping .

    run install.sh /opt/001-ping.tar.gz
    assert_success
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=T103,install
@test "T103: install.sh install --short" {
    run install.sh install --short
    assert_success
    assert_file_exist /usr/local/bin/gan.sh
    assert_teardown
}


# bats test_tags=T200,curlpipe
@test "T200: curl -s https://getansible.sh/ | sh" {
  run sh -c "curl -s https://getansible.sh/ | sh"
  assert_success
  assert_file_exist /usr/local/bin/getansible.sh
  assert_teardown
}

# bats test_tags=T201,curlpipe
@test "T201: curl -sL getansible.sh | sh" {
  run sh -c "curl -sL getansible.sh | sh"
  assert_success
  assert_file_exist /usr/local/bin/getansible.sh
  assert_teardown
}

# bats test_tags=T202,curlpipe
@test "T202: curl -sL getansible.sh | sh -s -- install" {
  run sh -c "curl -sL getansible.sh | sh -s -- install"
  assert_success
  assert_file_exist /usr/local/bin/getansible.sh
  assert_teardown
}

# bats test_tags=T203,curlpipe
@test "T203: curl https://getansible.sh/ | sh -s -- install --link" {
  run sh -c "curl -s https://getansible.sh/ | sh -s -- install --link"
  assert_success
  assert_file_exist /usr/local/bin/ansible
  assert_file_exist /usr/local/bin/ansible-galaxy
  assert_file_exist /usr/local/bin/ansible-playbook
  assert_teardown
}

# bats test_tags=T204,curlpipe
@test "T204: sh <(curl -sL getansible.sh)" {
  run sh <(curl -sL getansible.sh)
  assert_success
  assert_file_exist /usr/local/bin/getansible.sh
  assert_teardown
}

# bats test_tags=T205,curlpipe
@test "T205: sh <(curl -sL getansible.sh) " {
  run sh <(curl -sL getansible.sh) @andreygubarev/ping
  assert_success
  assert_teardown
}
