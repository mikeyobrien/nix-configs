{
  user,
  inputs,
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  sshdTmpDirectory = "${config.user.home}/sshd-tmp";
  sshdDirectory = "${config.user.home}/sshd";
  pathToPubKey = "${config.user.home}/host_pubkey";
  port = 8222;
in {
  user.shell = "${pkgs.fish}/bin/fish";

  build.activation.sshd = ''
    $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${config.user.home}/.ssh"
    $DRY_RUN_CMD cat ${pathToPubKey} > "${config.user.home}/.ssh/authorized_keys"

    if [[ ! -d "${sshdDirectory}" ]]; then
      $DRY_RUN_CMD rm $VERBOSE_ARG --recursive --force "${sshdTmpDirectory}"
      $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${sshdTmpDirectory}"

      $VERBOSE_ECHO "Generating host keys..."
      $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f "${sshdTmpDirectory}/ssh_host_rsa_key" -N ""

      $VERBOSE_ECHO "Writing sshd_config..."
      $DRY_RUN_CMD echo -e "HostKey ${sshdDirectory}/ssh_host_rsa_key\nPort ${toString port}\n" > "${sshdTmpDirectory}/sshd_config"

      $DRY_RUN_CMD mv $VERBOSE_ARG "${sshdTmpDirectory}" "${sshdDirectory}"
    fi
  '';

  # Simply install just the packages
  environment.packages = with pkgs; [
    alejandra
    # User-facing stuff that you really really want to have
    vim # or some other editor, e.g. nano or neovim
    git
    openssh
    # Some common stuff that people expect to have
    diffutils
    findutils
    utillinux
    tzdata
    hostname
    man
    gnugrep
    gnupg
    gnused
    gnutar
    bzip2
    gzip
    zip
    unzip

    (writeScriptBin "sshd-start" ''
      #!${runtimeShell}

      echo "Starting sshd in non-daemonized way on port ${toString port}"
      ${openssh}/bin/sshd -f "${sshdDirectory}/sshd_config" -D
    '')
  ];

  home-manager.config = ./hosts/droid/home.nix;
  home-manager.extraSpecialArgs = {
    user = user;
    inputs = inputs;
  };

  # Backup etc files instead of failing to activate generation if a file already exists in /etc
  environment.etcBackupExtension = ".bak";

  terminal.font = "${pkgs.terminus_font_ttf}/share/fonts/truetype/TerminusTTF.ttf";

  # Read the changelog before changing this value
  system.stateVersion = "23.11";

  # Set up nix for flakes
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Set your time zone
  #time.timeZone = "Europe/Berlin";
}
