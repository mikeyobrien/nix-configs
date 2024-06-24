{ inputs, currentSystem, ... }: {
  environment.systemPackages = [ inputs.agenix.packages.${currentSystem}.default ];
  age.secrets.password.file = ../secrets/password.age;
}
