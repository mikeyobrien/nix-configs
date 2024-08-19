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
  age.secrets.influxdb_token.file = ../secrets/influxdb_token.age;
}
