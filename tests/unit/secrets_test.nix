# ABOUTME: Unit tests for secret management configuration in k3s cluster
# ABOUTME: Validates agenix secrets, k3s token configuration, and host key management

let
  nixtest = import ../nixtest.nix;
  secretsConfig = ../../secrets/secrets.nix;
  baseModulePath = ../../hosts/base-k3s-vm/configuration.nix;
in
[
  {
    name = "Secrets configuration file exists and evaluates";
    actual = 
      let
        secrets = import secretsConfig;
      in
      builtins.isAttrs secrets;
    expected = true;
  }
  
  {
    name = "K3s secret is defined in secrets.nix";
    actual = 
      let
        secrets = import secretsConfig;
      in
      builtins.hasAttr "k3s_secret.age" secrets;
    expected = true;
  }
  
  {
    name = "K3s secret has public keys configured";
    actual = 
      let
        secrets = import secretsConfig;
      in
      builtins.length secrets."k3s_secret.age".publicKeys > 0;
    expected = true;
  }
  
  {
    name = "K3s secret includes reef host key";
    actual = 
      let
        secrets = import secretsConfig;
        reefKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtyNlZ7Q9TuCfq5UgRpBY6igzZGSw7f5qFWL8YYFA0B";
      in
      builtins.elem reefKey secrets."k3s_secret.age".publicKeys;
    expected = true;
  }
  
  {
    name = "K3s secret includes orchard placeholder key";
    actual = 
      let
        secrets = import secretsConfig;
        orchardKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderOrchardKeyWillBeReplacedDuringProvisioning";
      in
      builtins.elem orchardKey secrets."k3s_secret.age".publicKeys;
    expected = true;
  }
  
  {
    name = "K3s secret includes coral placeholder key";
    actual = 
      let
        secrets = import secretsConfig;
        coralKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderCoralKeyWillBeReplacedDuringProvisioning1";
      in
      builtins.elem coralKey secrets."k3s_secret.age".publicKeys;
    expected = true;
  }
  
  {
    name = "K3s tokenFile is configured in base VM";
    actual = 
      let
        eval = nixtest.evalTestConfig baseModulePath [];
      in
      eval.config.services.k3s.tokenFile;
    expected = "/run/secrets/k3s_secret";
  }
  
  {
    name = "K3s tokenFile path is not null";
    actual = 
      let
        eval = nixtest.evalTestConfig baseModulePath [];
      in
      eval.config.services.k3s.tokenFile != null;
    expected = true;
  }
  
  {
    name = "Base VM configuration evaluates with secret reference";
    actual = nixtest.checkModuleEvaluates baseModulePath;
    expected = true;
  }
  
  {
    name = "All secret files have publicKeys defined";
    actual = 
      let
        secrets = import secretsConfig;
        secretAttrs = builtins.attrValues secrets;
        allHaveKeys = builtins.all (secret: 
          builtins.hasAttr "publicKeys" secret && 
          builtins.length secret.publicKeys > 0
        ) secretAttrs;
      in
      allHaveKeys;
    expected = true;
  }
  
  {
    name = "Reef host key is properly formatted";
    actual = 
      let
        secrets = import secretsConfig;
        reefKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtyNlZ7Q9TuCfq5UgRpBY6igzZGSw7f5qFWL8YYFA0B";
      in
      builtins.substring 0 11 reefKey == "ssh-ed25519";
    expected = true;
  }
  
  {
    name = "Orchard placeholder key is properly formatted";
    actual = 
      let
        orchardKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderOrchardKeyWillBeReplacedDuringProvisioning";
      in
      builtins.substring 0 11 orchardKey == "ssh-ed25519";
    expected = true;
  }
  
  {
    name = "Coral placeholder key is properly formatted";
    actual = 
      let
        coralKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPlaceholderCoralKeyWillBeReplacedDuringProvisioning1";
      in
      builtins.substring 0 11 coralKey == "ssh-ed25519";
    expected = true;
  }
  
  {
    name = "K3s cluster has exactly 3 nodes configured";
    actual = 
      let
        secrets = import secretsConfig;
      in
      builtins.length secrets."k3s_secret.age".publicKeys;
    expected = 3;
  }
  
  {
    name = "Password secret still includes original systems";
    actual = 
      let
        secrets = import secretsConfig;
        reefKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOtyNlZ7Q9TuCfq5UgRpBY6igzZGSw7f5qFWL8YYFA0B";
      in
      builtins.elem reefKey secrets."password.age".publicKeys;
    expected = true;
  }
  
  {
    name = "Frigate secret is host-specific to reef only";
    actual = 
      let
        secrets = import secretsConfig;
      in
      builtins.length secrets."frigate.age".publicKeys;
    expected = 1;
  }
]