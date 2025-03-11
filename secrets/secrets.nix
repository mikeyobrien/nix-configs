let
  driftwood = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM0bc6RDXsS4BXpSTBTafStZxywXAIphdmOlnf/y8k92";
  moss = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKqtxru8/9eZwmrZIGvrZFFEitIbQvn69jEvW/7WL4ow";
  reef = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtyNlZ7Q9TuCfq5UgRpBY6igzZGSw7f5qFWL8YYFA0B"; 
  systems = [
    driftwood
    moss
    reef
  ];
in {
  "password.age".publicKeys = systems;
  "influxdb_token.age".publicKeys = systems;
  "test.age".publicKeys = systems;
  "k3s_secret.age".publicKeys = systems;
  "extra-openai-models.age".publicKeys = systems;
  "frigate.age".publicKeys = [reef];
}
