{
  inputs,
  currentSystem,
  pkgs,
  ...
}: {

  environment.systemPackages = [
    inputs.agenix.packages.${currentSystem}.default
    pkgs.unzip
    pkgs.btop
  ];
  age.secrets.password.file = ../secrets/password.age;
  age.secrets.influxdb_token.file = ../secrets/influxdb_token.age;
  age.secrets.k3s_secret.file = ../secrets/k3s_secret.age;
  age.secrets.frigate.file = ../secrets/frigate.age;
}
