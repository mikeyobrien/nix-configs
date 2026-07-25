# CyberPower CP1500PFCLCDa (1500 VA / 1000 W) attached to reef over USB.
#
# Why: reef runs an i9-14900K (PL2 253 W) plus 2x RTX 3090. Both GPUs are
# capped at 220 W to stay inside the 1000 W budget. That cap costs real
# inference throughput -- SM clocks sit at ~880 MHz against a ~1700+ MHz
# boost -- so we want measured load, not spec-sheet arithmetic, before
# changing it.
#
# Device identity, confirmed from the USB descriptor rather than usb.ids:
#   iProduct   = CP1500PFCLCDa      <- the device own string
#   idVendor   = 0x0764  (Cyber Power System, Inc.)
#   idProduct  = 0x0601  (usb.ids mislabels this PID as PR1500LCDRT2U)
#   iSerial    = CXXPY7006643
#
# SECRET -- deliberately not in git. upsmon authenticates to upsd.
# Create it out of band, root-owned, mode 0600:
#
#   umask 077
#   head -c 32 /dev/urandom | base64 | sudo tee /etc/nut/upsmon.password
#   sudo chmod 600 /etc/nut/upsmon.password
#
# After rebuild, read live telemetry:
#   upsc cyberpower                    # all variables
#   upsc cyberpower ups.realpower      # watts drawn -- the number we care about
#   upsc cyberpower ups.load           # percent of rated capacity
#   upsc cyberpower battery.runtime    # seconds remaining at current load
{ pkgs, ... }:

{
  power.ups = {
    enable = true;
    mode = "standalone";

    ups.cyberpower = {
      driver = "usbhid-ups";
      port = "auto";
      description = "CyberPower CP1500PFCLCDa 1500VA/1000W";
      directives = [
        # Pin by VID/PID so a USB renumber cannot bind a different HID device.
        # reef also exposes PiKVM, Logitech receivers and MSI Mystic Light on hidraw.
        "vendorid = 0764"
        "productid = 0601"
        # CyberPower HID reports are slow; tighter polling causes data-stale flapping.
        "pollinterval = 5"
      ];
    };

    users.upsmon = {
      passwordFile = "/etc/nut/upsmon.password";
      upsmon = "primary";
    };

    upsmon.monitor.cyberpower = {
      system = "cyberpower@localhost";
      user = "upsmon";
      passwordFile = "/etc/nut/upsmon.password";
      type = "primary";
    };
  };

  # upsc / upscmd / upsrw on PATH for manual queries.
  environment.systemPackages = [ pkgs.nut ];

  # UPS load alarm.
  #
  # Alerts via Telegram when the UPS approaches or exceeds its 1000 W rating.
  # This does NOT duplicate upsmon: upsmon handles UPS *events* (on battery,
  # low battery, shutdown). This handles sustained *load*, which upsmon
  # ignores entirely and which is the failure mode this box actually has --
  # see the nvidia-power-limit comment about two hard reboots at 275 W/GPU.
  #
  # Deliberately two-tier. Alarming only at 100% would fire when the UPS is
  # already in overload and about to drop the load; WARN at 85% gives lead
  # time to stop a job or drop a GPU cap.
  #
  # Alerts do NOT route through Alertmanager: reef's Alertmanager has a single
  # receiver named "null" and its default route points at it, so everything
  # sent there is discarded.
  #
  # They also do NOT go to ntfy: ntfy.sh free tier returns HTTP 429
  # "daily message quota reached", so those sends are dropped silently.
  #
  # Telegram direct instead, to the Crons topic.
  # SECRET: /etc/telegram/alerts.env (root, 0600), not in git. Provides
  # TELEGRAM_BOT_TOKEN, TELEGRAM_HOME_CHANNEL, TELEGRAM_CRON_THREAD_ID.
  systemd.services.ups-load-alarm = {
    description = "Alert via Telegram when UPS load crosses warning/critical thresholds";
    after = [ "upsd.service" "network-online.target" ];
    path = [ pkgs.nut pkgs.curl pkgs.coreutils ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -uo pipefail

      STATE=/run/ups-load-alarm.state
      WARN=85
      CRIT=100
      RENOTIFY=900   # re-alert every 15 min while still breached

      load="$(upsc cyberpower ups.load 2>/dev/null || true)"
      # Driver hiccup or UPS unreachable: upsmon owns that failure, not us.
      if [ -z "''${load}" ]; then exit 0; fi
      load="''${load%%.*}"

      status="$(upsc cyberpower ups.status 2>/dev/null || echo unknown)"
      runtime="$(upsc cyberpower battery.runtime 2>/dev/null || echo 0)"
      nominal="$(upsc cyberpower ups.realpower.nominal 2>/dev/null || echo 1000)"
      watts="$(( load * nominal / 100 ))"

      if [ "''${load}" -ge "''${CRIT}" ]; then
        level=crit
      elif [ "''${load}" -ge "''${WARN}" ]; then
        level=warn
      else
        level=ok
      fi

      prev=ok
      prev_ts=0
      if [ -r "''${STATE}" ]; then
        read -r prev prev_ts < "''${STATE}" || true
      fi
      now="$(date +%s)"

      notify=0
      if [ "''${level}" != "''${prev}" ]; then
        notify=1
      elif [ "''${level}" != "ok" ] && [ "$(( now - prev_ts ))" -ge "''${RENOTIFY}" ]; then
        notify=1
      fi

      if [ "''${notify}" -eq 1 ]; then
        # shellcheck disable=SC1091
        . /etc/telegram/alerts.env

        case "''${level}" in
          crit) title="🚨 UPS OVERLOAD ''${load}% on reef" ;;
          warn) title="⚠️ UPS load ''${load}% on reef" ;;
          *)    title="✅ UPS load recovered: ''${load}% on reef" ;;
        esac

        text="''${title}

load: ''${load}% (~''${watts}W of ''${nominal}W)
status: ''${status}
battery runtime: ''${runtime}s
thresholds: warn ''${WARN}% / crit ''${CRIT}%"

        code="$(curl -sS --max-time 15 -o /dev/null -w "%{http_code}" \
          -X POST "https://api.telegram.org/bot''${TELEGRAM_BOT_TOKEN}/sendMessage" \
          --data-urlencode "chat_id=''${TELEGRAM_HOME_CHANNEL}" \
          --data-urlencode "message_thread_id=''${TELEGRAM_CRON_THREAD_ID}" \
          --data-urlencode "text=''${text}" || echo 000)"

        # Log delivery outcome so a silently-dropped alarm is visible in journalctl.
        echo "ups-load-alarm: level=''${level} load=''${load}% telegram_http=''${code}"

        printf '%s %s\n' "''${level}" "''${now}" > "''${STATE}"
      else
        printf '%s %s\n' "''${level}" "''${prev_ts}" > "''${STATE}"
      fi
    '';
  };

  systemd.timers.ups-load-alarm = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3min";
      OnUnitActiveSec = "1min";
      Unit = "ups-load-alarm.service";
    };
  };
}
