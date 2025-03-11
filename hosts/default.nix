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
  # TODO move this to llm module
  age.secrets.extra-openai-models = {
    path = "/etc/secrets/extra-openai-models.yaml";
    file = ../secrets/extra-openai-models.age;
    mode = "0660";
    owner = "root";
    group = "wheel";
  };
  age.secrets.k3s_secret.file = ../secrets/k3s_secret.age;
  age.secrets.frigate.file = ../secrets/frigate.age;
}
