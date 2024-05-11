@test "getansible.sh -- ansible" {
  run getansible.sh -- ansible --version
  [ "$status" -eq 0 ]
}


@test "getansible.sh -- ansible-playbook" {
  run getansible.sh -- ansible-playbook --version
  [ "$status" -eq 0 ]
}


@test "getansible.sh -- ansible-galaxy" {
  run getansible.sh -- ansible-galaxy --version
  [ "$status" -eq 0 ]
}
