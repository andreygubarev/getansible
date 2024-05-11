@test "getansible.sh" {
  run getansible.sh -- ansible --version
  [ "$status" -eq 0 ]
}
