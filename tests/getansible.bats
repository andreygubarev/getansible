#!/usr/bin/env bash

setup() {
    bats_load_library bats-assert
    bats_load_library bats-file
    bats_load_library bats-support

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

# bats test_tags=0001,getansible
@test "0001: getansible.sh" {
    run getansible.sh
    assert_failure 2
    assert_output --partial "Usage: getansible"
    assert_teardown
}

# bats test_tags=0002,getansible
@test "0002: getansible.sh -- ansible" {
    run getansible.sh -- ansible --version
    assert_success
    assert_teardown
}

# bats test_tags=0003,getansible
@test "0003: getansible.sh -- ansible-galaxy" {
    run getansible.sh -- ansible-galaxy --version
    assert_success
    assert_teardown
}

# bats test_tags=0004,getansible
@test "0004: getansible.sh -- ansible-playbook" {
    run getansible.sh -- ansible-playbook --version
    assert_success
    assert_teardown
}

# bats test_tags=0005,python
@test "0005: getansible.sh -- exec pip" {
    run bash -c "PIP_REQUIREMENTS='boto3 botocore' getansible.sh -- exec pip freeze | grep boto3"
    assert_success
    assert_teardown
}

# bats test_tags=0006,getansible,galaxy
@test "0006: getansible.sh -- geerlingguy.apache" {
    # skip unsupported ansible releases: 3.0, 4.0 and 5.0
    if [ -n "$(getansible.sh -- exec pip freeze | grep 'ansible==3\|ansible==4\|ansible==5')" ]; then
        skip
    fi

    run getansible.sh -- geerlingguy.apache
    assert_success
    assert_output --partial "geerlingguy.apache"
    assert_output --partial "failed=0"
    assert_teardown
}

# bats test_tags=0007,getansible,galaxy
@test "0007: getansible.sh -- andreygubarev.core.ping" {
    # skip unsupported ansible releases: 3.0, 4.0 and 5.0
    if [ -n "$(getansible.sh -- exec pip3 freeze | grep 'ansible==3\|ansible==4\|ansible==5')" ]; then
        skip
    fi

    run getansible.sh -- andreygubarev.core.ping
    assert_success
    assert_output --partial "andreygubarev.core.ping : Ping"
    assert_output --partial "failed=0"
    assert_teardown
}

# bats test_tags=0008,getansible,galaxy
@test "0008: getansible.sh -- andreygubarev.core.ping 0.7.3" {
    # skip unsupported ansible releases: 3.0, 4.0, 5.0, 6.0 and 7.0
    if [ -n "$(getansible.sh -- exec pip3 freeze | grep 'ansible==3\|ansible==4\|ansible==5\|ansible==6\|ansible==7')" ]; then
        skip
    fi

    run getansible.sh -- andreygubarev.core.ping 0.7.3
    assert_success
    assert_output --partial "andreygubarev.core.ping : Ping"
    assert_output --partial "failed=0"
    assert_teardown
}

# bats test_tags=0009,getansible,galaxy
@test "0009: getansible.sh -- andreygubarev.core.ping 0.7.0" {
    # skip unsupported ansible releases: 3.0, 4.0, 5.0, 6.0 and 7.0
    if [ -n "$(getansible.sh -- exec pip3 freeze | grep 'ansible==3\|ansible==4\|ansible==5\|ansible==6\|ansible==7')" ]; then
        skip
    fi

    run getansible.sh -- andreygubarev.core.ping 0.7.0
    assert_failure  # version 0.7.0 does not have a ping role
    assert_teardown
}

# bats test_tags=0010,playbook
@test "0010: getansible.sh -- /opt/001-ping.tar.gz" {
    tar -czf /opt/001-ping.tar.gz -C /usr/src/bats/examples/001-ping .

    run getansible.sh -- /opt/001-ping.tar.gz
    assert_success
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=0011,playbook
@test "0011: getansible.sh -- 001-ping.tar.gz" {
    tar -czf /opt/001-ping.tar.gz -C /usr/src/bats/examples/001-ping .
    pushd /opt > /dev/null || exit 1

    run getansible.sh -- 001-ping.tar.gz
    assert_success
    assert_output --partial "ok=1"

    popd > /dev/null || exit 1
    assert_teardown
}

# bats test_tags=0012,playbook
@test "0012: getansible.sh -- /opt/002-requirements.tar.gz" {
    tar -czf /opt/002-requirements.tar.gz -C /usr/src/bats/examples/002-requirements .

    run getansible.sh -- /opt/002-requirements.tar.gz
    assert_success
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=0013,playbook
@test "0013: getansible.sh -- /opt/003-roles.tar.gz" {
    tar -czf /opt/003-roles.tar.gz -C /usr/src/bats/examples/003-roles .

    run getansible.sh -- /opt/003-roles.tar.gz
    assert_success
    assert_output --partial '"msg": "getansible"'
    assert_output --partial "ok=2"
    assert_teardown
}

# bats test_tags=0014,playbook
@test "0014: getansible.sh --/opt/004-subfolder.tar.gz" {
    tar -czf /opt/004-subfolder.tar.gz -C /usr/src/bats/examples/004-subfolder .

    run getansible.sh -- /opt/004-subfolder.tar.gz
    assert_success
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=0015,playbook
@test "0015: getansible.sh -- /opt/005-dotenv.tar.gz" {
    tar -czf /opt/005-dotenv.tar.gz -C /usr/src/bats/examples/005-dotenv .

    run getansible.sh -- /opt/005-dotenv.tar.gz
    assert_success
    assert_output --partial "FOO=BAR"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=0016,playbook
@test "0016: getansible.sh -- /opt/005-dotenv.tar.gz" {
    tar -czf /opt/005-dotenv.tar.gz -C /usr/src/bats/examples/005-dotenv .

    export FOO=BAZ
    run getansible.sh -- /opt/005-dotenv.tar.gz
    assert_success
    assert_output --partial "FOO=BAZ"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=0017,playbook,inventory
@test "0017: getansible.sh -- /opt/006-inventory.tar.gz" {
    tar -czf /opt/006-inventory.tar.gz -C /usr/src/bats/examples/006-inventory .

    run getansible.sh -- /opt/006-inventory.tar.gz <<-EOF
---
ungrouped:
  hosts:
    localhost:
      foo: bar
EOF
    assert_success
    assert_output --partial "foo=bar"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=0018,playbook,inventory
@test "0018: getansible.sh -- /opt/006-inventory.tar.gz" {
    tar -czf /opt/006-inventory.tar.gz -C /usr/src/bats/examples/006-inventory .

    run getansible.sh -- /opt/006-inventory.tar.gz <<-EOF
localhost foo=bar
EOF
    assert_success
    assert_output --partial "foo=bar"
    assert_output --partial "ok=1"
    assert_teardown
}

# bats test_tags=0100,install
@test "0100: install.sh install" {
    run install.sh install
    assert_success
    assert_file_exist /usr/local/bin/getansible.sh
    assert_teardown
}

# bats test_tags=0101,install
@test "0101: install.sh install --link" {
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

bats test_tags=0102,install
@test "install.sh /opt/001-ping.tar.gz" {
    tar -czf /opt/001-ping.tar.gz -C /usr/src/bats/examples/001-ping .

    run install.sh /opt/001-ping.tar.gz
    assert_success
    assert_output --partial "ok=1"
    assert_teardown
}


# # bats test_tags=curlpipe
# @test "curl https://getansible.sh/ | bash" {
#   run bash -c "curl -s https://getansible.sh/ | bash"
#   assert_success
#   assert_teardown
# }

# # bats test_tags=curlpipe
# @test "curl https://getansible.sh/ | bash -" {
#   run bash -c "curl -s https://getansible.sh/ | bash -"
#   assert_success
#   assert_teardown
# }

# # bats test_tags=curlpipe
# @test "curl https://getansible.sh/ | bash -s -- install --link" {
#   run bash -c "curl -sL https://getansible.sh/ | bash -s -- install --link"
#   assert_success
#   assert_file_exist /usr/local/bin/ansible
#   assert_file_exist /usr/local/bin/ansible-galaxy
#   assert_file_exist /usr/local/bin/ansible-playbook
#   assert_teardown
# }
