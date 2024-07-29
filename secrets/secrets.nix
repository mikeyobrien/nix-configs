let
  driftwood = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM0bc6RDXsS4BXpSTBTafStZxywXAIphdmOlnf/y8k92";
  moss = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKqtxru8/9eZwmrZIGvrZFFEitIbQvn69jEvW/7WL4ow";
  systems = [
    driftwood
    moss
  ];
in {
  "password.age".publicKeys = systems;
  "influxdb_token.age".publicKeys = systems;
  "test.age".publicKeys = systems;
}
