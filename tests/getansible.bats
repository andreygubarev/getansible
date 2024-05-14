setup() {
    bats_load_library bats-assert
    bats_load_library bats-file
    bats_load_library bats-support
}

@test "getansible.sh" {
  run getansible.sh
  assert_failure 2
  assert_output --partial "Usage: getansible"
}

@test "getansible.sh -- ansible" {
  run getansible.sh -- ansible --version
  assert_success
}


@test "getansible.sh -- ansible-playbook" {
  run getansible.sh -- ansible-playbook --version
  assert_success
}


@test "getansible.sh -- ansible-galaxy" {
  run getansible.sh -- ansible-galaxy --version
  assert_success
}


@test "PYTHON_REQUIREMENTS getansible.sh" {
  run bash -c "PYTHON_REQUIREMENTS='boto3 botocore' getansible.sh -- exec pip3 freeze | grep boto3"
  assert_success
}

# bats test_tags=playbook
@test "getansible.sh -- file://" {
  run bash -c "getansible.sh -- file:///usr/src/bats/examples/ping.tar.gz"
  assert_success
  assert_output --partial "ok=1"
}


# bats test_tags=curlpipe
@test "curl https://getansible.sh/ | bash" {
  run bash -c "curl -s https://getansible.sh/ | bash"
  assert_success
}


# bats test_tags=curlpipe
@test "curl https://getansible.sh/ | bash -" {
  run bash -c "curl -s https://getansible.sh/ | bash -"
  assert_success
}

# bats test_tags=curlpipe
@test "curl https://getansible.sh/ | bash -s -- install --link" {
  run bash -c "curl -sL https://getansible.sh/ | bash -s -- install --link"
  assert_success
  assert_file_exist /usr/local/bin/ansible
  assert_file_exist /usr/local/bin/ansible-galaxy
  assert_file_exist /usr/local/bin/ansible-playbook
}


# bats test_tags=install
@test "install.sh" {
  run install.sh install
  assert_success
  assert_file_exist /usr/local/bin/getansible.sh
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
}
