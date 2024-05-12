setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
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
