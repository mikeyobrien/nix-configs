{
  inputs,
  currentSystem,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    inputs.agenix.packages.${currentSystem}.default
    pkgs.unzip
  ];
  age.secrets.password.file = ../secrets/password.age;
}
