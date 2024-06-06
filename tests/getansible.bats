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

@test "getansible.sh" {
  run getansible.sh
  assert_failure 2
  assert_output --partial "Usage: getansible"
  assert_teardown
}

@test "getansible.sh -- ansible" {
  run getansible.sh -- ansible --version
  assert_success
  assert_teardown
}

@test "getansible.sh -- ansible-playbook" {
  run getansible.sh -- ansible-playbook --version
  assert_success
  assert_teardown
}

@test "getansible.sh -- ansible-galaxy" {
  run getansible.sh -- ansible-galaxy --version
  assert_success
  assert_teardown
}

@test "PYTHON_REQUIREMENTS getansible.sh" {
  run bash -c "PYTHON_REQUIREMENTS='boto3 botocore' getansible.sh -- exec pip3 freeze | grep boto3"
  assert_success
  assert_teardown
}

# bats test_tags=playbook,galaxy
@test "getansible.sh -- galaxy with role" {
  # skip unsupported ansible releases: 3.0, 4.0 and 5.0
  if [ -n "$(getansible.sh -- exec pip3 freeze | grep 'ansible==3\|ansible==4\|ansible==5')" ]; then
    skip
  fi

  run getansible.sh -- galaxy://geerlingguy.apache
  assert_success
  assert_output --partial "geerlingguy.apache"
  assert_output --partial "failed=0"
  assert_teardown
}

# bats test_tags=playbook,galaxy
@test "getansible.sh -- galaxy with collection" {
  # skip unsupported ansible releases: 3.0, 4.0 and 5.0
  if [ -n "$(getansible.sh -- exec pip3 freeze | grep 'ansible==3\|ansible==4\|ansible==5')" ]; then
    skip
  fi

  run getansible.sh -- galaxy://andreygubarev.core.ping
  assert_success
  assert_output --partial "andreygubarev.core.ping : Ping"
  assert_output --partial "failed=0"
  assert_teardown
}

# bats test_tags=playbook,galaxy1
@test "getansible.sh -- galaxy with collection with version" {
  # skip unsupported ansible releases: 3.0, 4.0, 5.0, 6.0 and 7.0
  if [ -n "$(getansible.sh -- exec pip3 freeze | grep 'ansible==3\|ansible==4\|ansible==5\|ansible==6\|ansible==7')" ]; then
    skip
  fi

  run getansible.sh -- galaxy://andreygubarev.core.ping==0.7.3
  assert_success
  assert_output --partial "andreygubarev.core.ping : Ping"
  assert_output --partial "failed=0"
  assert_teardown

  run getansible.sh -- galaxy://andreygubarev.core.ping==0.7.0
  assert_failure  # version 0.7.0 does not have a ping role
  assert_teardown
}

# bats test_tags=playbook
@test "getansible.sh -- file:// with absolute path" {
  tar -czf /opt/001-ping.tar.gz -C /usr/src/bats/examples/001-ping .

  run getansible.sh -- file:///opt/001-ping.tar.gz
  assert_success
  assert_output --partial "ok=1"
  assert_teardown
}

# bats test_tags=playbook
@test "getansible.sh -- file:// with relative path" {
  tar -czf /opt/001-ping.tar.gz -C /usr/src/bats/examples/001-ping .
  pushd /opt > /dev/null || exit 1

  run getansible.sh -- file://001-ping.tar.gz
  assert_success
  assert_output --partial "ok=1"

  popd > /dev/null || exit 1
  assert_teardown
}

# bats test_tags=playbook
@test "getansible.sh -- file:// with requirements.yml" {
  tar -czf /opt/002-requirements.tar.gz -C /usr/src/bats/examples/002-requirements .

  run getansible.sh -- file:///opt/002-requirements.tar.gz
  echo $output
  assert_success
  assert_output --partial "ok=1"
  assert_teardown
}

# bats test_tags=playbook,role
@test "getansible.sh -- file:// with roles" {
  tar -czf /opt/003-roles.tar.gz -C /usr/src/bats/examples/003-roles .

  run getansible.sh -- file:///opt/003-roles.tar.gz
  echo $output
  assert_success
  assert_output --partial '"msg": "getansible"'
  assert_output --partial "ok=2"
  assert_teardown
}

# bats test_tags=playbook,subfolder
@test "getansible.sh -- file:// with subfolder" {
  tar -czf /opt/004-subfolder.tar.gz -C /usr/src/bats/examples/004-subfolder .

  run getansible.sh -- file:///opt/004-subfolder.tar.gz
  assert_success
  assert_output --partial "ok=1"
  assert_teardown
}

# bats test_tags=playbook,subfolder
@test "install.sh file:// with multiple subfolders" {
  tar -czf /opt/007-subfolders.tar.gz -C /usr/src/bats/examples/007-subfolders .

  run getansible.sh -- file:///opt/007-subfolders.tar.gz
  assert_failure
  assert_teardown

  run getansible.sh -- file:///opt/007-subfolders.tar.gz#ping
  assert_success
  assert_output --partial "ok=1"
  assert_teardown

  run getansible.sh -- file:///opt/007-subfolders.tar.gz#foobar
  assert_failure
  assert_teardown

  run getansible.sh -- file:///opt/007-subfolders.tar.gz#pong
  assert_success
  assert_output --partial "ok=1"
  assert_teardown
}

# bats test_tags=playbook
@test "install.sh file:// with dotenv" {
  tar -czf /opt/005-dotenv.tar.gz -C /usr/src/bats/examples/005-dotenv .

  run getansible.sh -- file:///opt/005-dotenv.tar.gz
  assert_success
  assert_output --partial "FOO=BAR"
  assert_output --partial "ok=1"
  assert_teardown
}

# bats test_tags=playbook
@test "install.sh file:// with dotenv with overrides" {
  tar -czf /opt/005-dotenv.tar.gz -C /usr/src/bats/examples/005-dotenv .

  export FOO=BAZ
  run getansible.sh -- file:///opt/005-dotenv.tar.gz
  assert_success
  assert_output --partial "FOO=BAZ"
  assert_output --partial "ok=1"
  assert_teardown
}

# bats test_tags=playbook,inventory
@test "install.sh file:// with inventory in yaml format" {
  tar -czf /opt/006-inventory.tar.gz -C /usr/src/bats/examples/006-inventory .

  run getansible.sh -- file:///opt/006-inventory.tar.gz <<-EOF
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

# bats test_tags=playbook,inventory
@test "install.sh file:// with inventory in ini format" {
  tar -czf /opt/006-inventory.tar.gz -C /usr/src/bats/examples/006-inventory .

  run getansible.sh -- file:///opt/006-inventory.tar.gz <<-EOF
localhost foo=bar
EOF
  assert_success
  assert_output --partial "foo=bar"
  assert_output --partial "ok=1"
  assert_teardown
}

# bats test_tags=curlpipe
@test "curl https://getansible.sh/ | bash" {
  run bash -c "curl -s https://getansible.sh/ | bash"
  assert_success
  assert_teardown
}

# bats test_tags=curlpipe
@test "curl https://getansible.sh/ | bash -" {
  run bash -c "curl -s https://getansible.sh/ | bash -"
  assert_success
  assert_teardown
}

# bats test_tags=curlpipe
@test "curl https://getansible.sh/ | bash -s -- install --link" {
  run bash -c "curl -sL https://getansible.sh/ | bash -s -- install --link"
  assert_success
  assert_file_exist /usr/local/bin/ansible
  assert_file_exist /usr/local/bin/ansible-galaxy
  assert_file_exist /usr/local/bin/ansible-playbook
  assert_teardown
}

# bats test_tags=install
@test "install.sh" {
  run install.sh install
  assert_success
  assert_file_exist /usr/local/bin/getansible.sh
  assert_teardown
}

# bats test_tags=install
@test "install.sh --link" {
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

# bats test_tags=install
@test "install.sh file://" {
  tar -czf /opt/001-ping.tar.gz -C /usr/src/bats/examples/001-ping .

  run install.sh file:///opt/001-ping.tar.gz
  assert_success
  assert_output --partial "ok=1"

  assert_teardown
}
