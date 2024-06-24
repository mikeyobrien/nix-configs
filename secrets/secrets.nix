let 
  driftwood = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM0bc6RDXsS4BXpSTBTafStZxywXAIphdmOlnf/y8k92";
  moss = "";
  systems = [ driftwood moss ];
in 
{
  "password.age".publicKeys = systems;
}
