setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
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
