{
  user,
  pkgs,
  inputs,
  ...
}: {
  imports = [../../home-manager/home.nix];
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };

  # hyprland
  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.systemd.extraCommands = [
    "waybar"
  ];
  wayland.windowManager.hyprland.settings = {
    general = {
      gaps_in = 5;
      gaps_out = 5;
      border_size = 2;
      "col.active_border" = "rgba(404040ee)";
      "col.inactive_border" = "rgba(595959aa)";
      allow_tearing = true;
      resize_on_border = true;
    };

    input = {
      kb_options = "ctrl:nocaps";
    };

    decoration = {
      rounding = 8;
      blur = {
        enabled = true;
        brightness = 1.0;
        contrast = 1.0;
        noise = 0.01;

        vibrancy = 0.2;
        vibrancy_darkness = 0.5;

        passes = 4;
        size = 7;

        popups = true;
        popups_ignorealpha = 0.2;
      };

      drop_shadow = true;
      shadow_ignore_window = true;
      shadow_offset = "0 2";
      shadow_range = 20;
      shadow_render_power = 3;
      "col.shadow" = "rgba(00000055)";
    };

    windowrulev2 = [
      "float,class:(clipse)"
      "size 622 652,class:(clipse)"
    ];

    exec-once = [
      "clipse -listen"
      "~/.config/hypr/suspend.sh"
    ];
    "$mod" = "SUPER";
    bindm = [
      "$mod, mouse:272, movewindow"
      "$mod, mouse:273, resizewindow"
      "$mod ALT, mouse:272, resizewindow"
    ];
    bind =
      [
        "$mod, F, exec, firefox"
        "$mod, Q, exec, alacritty"
        "$mod, R, exec, anyrun"
        "$mod, P, pseudo"
        "$mod, J, togglesplit"
        "$mod, V, exec, alacritty --class clipse -e \'clipse\'"
        "$mod SHIFT, V, exec, cliphist list | anyrun -d | cliphist delete"
        "$mod SHIFT, Q, killactive"
        "$mod, M, exit"
        "$mod, h, movefocus, l"
        "$mod, j, movefocus, d"
        "$mod, k, movefocus, u"
        "$mod, l, movefocus, r"
        "$mod SHIFT, h, swapwindow, l"
        "$mod SHIFT, j, swapwindow, d"
        "$mod SHIFT, k, swapwindow, u"
        "$mod SHIFT, l, swapwindow, r"
        ", Print, exec, grimblast copy area"
        "ALT SHIFT, 2, exec, grimblast --notify copysave active"
        "ALT SHIFT, 3, exec, grimblast --notify copysave screen"
        "ALT SHIFT, 4, exec, grimblast --notify copysave area"
        "ALT CTRL SHIFT, 4, exec, grimblast --notify save area"
      ]
      ++ (
        # workspaces
        # binds $mod + [shift +] {1..10} to [move to] workspace {1..10}
        builtins.concatLists (builtins.genList (
            x: let
              ws = let
                c = (x + 1) / 10;
              in
                builtins.toString (x + 1 - (c * 10));
            in [
              "$mod, ${ws}, workspace, ${toString (x + 1)}"
              "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
            ]
          )
          10)
      );

    monitor = [
      "HDMI-A-1,3840x2160@120,0x0,1"
      "DP-3,1920x1080,3840x540,1"
      "HEADLESS-2,1920x1080@120,5760x0,1"
    ];

    workspace = [
      "1,monitor:HDMI-A-1"
      "2,monitor:HDMI-A-1"
      "3,monitor:HDMI-A-1"
      "4,monitor:HDMI-A-1"
      "5,monitor:HDMI-A-1"
      "6,monitor:HDMI-A-1"
      "7,monitor:HDMI-A-1"
      "8,monitor:HDMI-A-1"
      "9,monitor:DP-3"
      "0,monitor:DP-3"
    ];

    windowrule = [
      "float,^(anyrun)$"
      "move 0 50,^(anyrun)$"
      "size 1200 50,^(anyrun)$"
      "center,^(anyrun)$"
      "size 800 600,^(Bitwarden)$"
      "center,^(Bitwarden)$"
    ];
  };

  # waybar
  programs.waybar = {
    enable = true;
    style = ''
      * {
          border: none;
          border-radius: 0;
          font-family: "JetBrainsMono Nerd Font";
          font-size: 32px;
          min-height: 0;
      }

      window#waybar {
          background: rgba(30, 30, 46, 0.5);
          color: #cdd6f4;
      }

      #custom-logo {
          font-size: 68px;
          padding: 0 25px;
          color: #89b4fa;
      }

      #workspaces button {
          padding: 5px;
          color: #6c7086;
      }

      #workspaces button.active {
          color: #cdd6f4;
      }

      #idle_inhibitor {
          padding: 0 25px;
          margin: 0 5px;
      }

      #clock, #custom-weather, #cpu, #memory, #temperature, #custom-gpu, #network, #pulseaudio {
          padding: 0 10px;
          margin: 0 5px;
          background-color: #313244;
          border-radius: 10px;
      }

      #custom-media {
          background-color: #313244;
          padding: 0 10px;
          margin: 0 5px;
          border-radius: 10px;
          color: #f9e2af;
      }
    '';

    settings = [
      {
        layer = "top";
        position = "top";
        height = 120;
        width = 3840;
        output = "HDMI-A-1";
        modules-left = ["custom/logo" "hyprland/workspaces" "custom/weather" "idle_inhibitor"];
        modules-center = ["clock" "custom/media"];
        modules-right = ["cpu" "memory" "temperature" "custom/gpu" "network" "pulseaudio"];
        "custom/logo" = {
          format = "󱄅";
          tooltip = false;
        };
        "hyprland/workspaces" = {
          disable-scroll = true;
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            "1" = "1";
            "2" = "2";
            "3" = "3";
            "4" = "4";
            "5" = "5";
            "6" = "6";
            "7" = "7";
            "8" = "8";
            "9" = "9";
            "10" = "10";
            "urgent" = "";
            "focused" = "";
            "default" = "";
          };
        };
        "custom/weather" = {
          exec = "curl 'https://wttr.in/Austin?u&format=1'";
          interval = 3600;
        };
        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            "activated" = "";
            "deactivated" = "";
          };
          timeout = 30.5;
        };
        "clock" = {
          format = "{:%Y-%m-%d %H:%M}";
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
        };
        "cpu" = {
          format = "{usage}% ";
          tooltip = false;
        };
        "memory" = {
          format = "{}% ";
        };
        "temperature" = {
          critical-threshold = 80;
          format = "{temperatureC}°C {icon}";
          format-icons = ["" "" ""];
        };
        "network" = {
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "{ipaddr}/{cidr} ";
          tooltip-format = "{ifname} via {gwaddr} ";
          format-linked = "{ifname} (No IP) ";
          format-disconnected = "Disconnected ⚠";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
        };
        "pulseaudio" = {
          format = "{volume}% {icon} {format_source}";
          format-bluetooth = "{volume}% {icon} {format_source}";
          format-bluetooth-muted = " {icon} {format_source}";
          format-muted = " {format_source}";
          format-source = "{volume}% ";
          format-source-muted = "";
          format-icons = {
            "headphone" = "";
            "hands-free" = "";
            "headset" = "";
            "phone" = "";
            "portable" = "";
            "car" = "";
            "default" = ["" "" ""];
          };
          on-click = "pavucontrol";
        };
      }
    ];
  };

  programs.anyrun = {
    enable = true;
    config = {
      plugins = with inputs.anyrun.packages.${pkgs.system}; [
        applications
        rink
        shell
        symbols
      ];
      x = {fraction = 0.5;};
      y = {fraction = 0.3;};
      width = {fraction = 0.3;};
      hideIcons = false;
      ignoreExclusiveZones = false;
      layer = "overlay";
      hidePluginInfo = false;
      closeOnClick = true;
      showResultsImmediately = false;
      maxEntries = null;
    };
    extraCss = builtins.readFile (./. + "/anyrun.css");
    extraConfigFiles."applications.ron".text = ''
      Config(
        desktop_actions: false,
        max_entries: 5,
        terminal: Some("foot"),
      )
    '';
  };

  home.file.".config/hypr/suspend.sh" = {
    text = ''
      #!/usr/bin/env bash
      swayidle -w \
      timeout 300 '${pkgs.lgtv} --ssl screenOff' \
      timeout 900 'systemctl suspend' \
      resume '${pkgs.lgtv} --ssl on' \
      before-sleep '${pkgs.lgtv} --ssl off'
    '';
    executable = true;
  };

  home.packages = with pkgs; [
    pavucontrol
    curl
    cliphist
    wl-clipboard
    clipse

    # screenshots
    grimblast
    slurp

    signal-desktop

    # productivity
    ticktick
  ];

  editors.nixvim = {
    enable = true;
    lazyPlugins.copilot.enable = true;
  };
}
