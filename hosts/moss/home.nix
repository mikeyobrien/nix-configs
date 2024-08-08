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
  programs.rofi = {
    enable = true;
    terminal = "${pkgs.alacritty}/bin/alacritty";
  };

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
      "xdg-mime default thunar.desktop inode/directory"
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
        "$mod, E, exec, thunar"
        "$mod, V, exec, alacritty --class clipse -e \'clipse\'"
        "$mod SHIFT, V, exec, cliphist list | anyrun -d | cliphist delete"
        "$mod SHIFT, Q, killactive"
        "$mod SHIFT, F, toggleFloating"
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
      "float,^(Signal)$"
    ];
  };

  home.file = {
    ".config/hypr/scripts/menu" = {
      text = ''
        #!/usr/bin/env bash
        if [[ ! $(pidof anyrun) ]]; then
          anyrun
        else
          pkill anyrun
        fi
      '';
      executable = true;
    };
  };

  # waybar
  programs.waybar = {
    enable = true;
    style = builtins.readFile (./. + "/waybar.css");

    settings = [
      {
        layer = "top";
        position = "top";
        height = 40;
        spacing = 4;
        output = "HDMI-A-1";

        modules-left = ["idle_inhibitor" "pulseaudio" "cpu" "memory" "temperature" "hyprland/workspaces"];
        modules-center = ["custom/launcher" "custom/media" "wlr/taskbar" "custom/power"];
        modules-right = ["keyboard-state" "network" "tray" "clock"];

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
          };
        };

        "keyboard-state" = {
          numlock = true;
          capslock = true;
          format = " {name} {icon}";
          format-icons = {
            locked = "";
            unlocked = "";
          };
        };

        "wlr/taskbar" = {
          format = "{icon}";
          icon-size = 20;
          icon-theme = "Star";
          tooltip-format = "{title}";
          on-click = "minimize";
          on-click-middle = "close";
          on-click-right = "activate";
        };

        "sway/language" = {
          format = " {}";
        };

        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            activated = "";
            deactivated = "";
          };
        };

        tray = {
          icon-size = 20;
          spacing = 10;
        };

        clock = {
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format-alt = "{:%Y-%m-%d}";
        };

        cpu = {
          format = "{usage}% ";
          tooltip = false;
        };

        memory = {
          format = "{}% ";
        };

        temperature = {
          critical-threshold = 80;
          format = "{temperatureC}°C {icon}";
          format-icons = ["" "" ""];
        };

        backlight = {
          format = "{percent}% {icon}";
          format-icons = ["" ""];
        };

        network = {
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "Connected  ";
          tooltip-format = "{ifname} via {gwaddr} ";
          format-linked = "{ifname} (No IP) ";
          format-disconnected = "Disconnected ⚠";
          format-alt = "{ifname}: {ipaddr}/{cidr}";
          on-click-right = "bash ~/.config/rofi/wifi_menu/rofi_wifi_menu";
        };

        pulseaudio = {
          format = "{volume}% {icon}";
          format-bluetooth = "{volume}% {icon}";
          format-bluetooth-muted = "{icon} {format_source}";
          format-muted = "{format_source}";
          format-source = "";
          format-source-muted = "";
          format-icons = {
            headphone = "";
            hands-free = "";
            headset = "";
            phone = "";
            portable = "";
            car = "";
            default = ["" "" ""];
          };
          on-click = "pavucontrol";
        };

        "custom/media" = {
          format = "{icon} {}";
          return-type = "json";
          max-length = 15;
          format-icons = {
            spotify = " ";
            default = "M ";
          };
          escape = true;
          exec = "$HOME/.config/system_scripts/mediaplayer.py 2> /dev/null";
          on-click = "playerctl play-pause";
        };

        "custom/launcher" = {
          format = "  ";
          on-click = "$HOME/.config/hypr/scripts/menu";
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
      timeout 900 'systemctl suspend' \
    '';
    executable = true;
  };

  home.packages = with pkgs; [
    pavucontrol
    curl
    cliphist
    wl-clipboard
    clipse
    rofi
    xfce.thunar

    # screenshots
    grimblast
    slurp

    signal-desktop

    # productivity
    ticktick

    discord
    google-chrome
  ];

  editors.nixvim = {
    enable = true;
    lazyPlugins.copilot.enable = true;
  };
}
