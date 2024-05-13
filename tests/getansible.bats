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


# bats test_tags=curlpipe
@test "curl https://getansible.sh/" {
  run bash -c "curl -s https://getansible.sh/ | bash -"
  assert_success
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
