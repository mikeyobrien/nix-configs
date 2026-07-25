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
}
