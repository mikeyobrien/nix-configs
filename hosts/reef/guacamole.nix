{ config
, lib
, pkgs
, ...
}: {
  services.guacamole-server = {
    enable = true;
    host = "127.0.0.1";
    userMappingXml = ./guacamole/user-mapping.xml;
  };

  services.guacamole-client = {
    enable = true;
    settings = {
      guacd-port = 4822;
      guacd-hostname = "localhost";
    };
  };

  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "startplasma-x11";

  services.caddy.virtualHosts."localhost".extraConfig = ''
    handle /* {
      reverse_proxy localhost:8080 {
         flush_interval -1
      }
    }
  '';
}
