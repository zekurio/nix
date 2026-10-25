{pkgs, ...}: {
  # uaccess must be tagged before 73-seat-late.rules applies the session ACL;
  # services.udev.extraRules would put these rules in 99-local.rules, too late.
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/70-webhid.rules" ''
      # Grant the active local user access to every HID interface for WebHID.
      # Pulsar 4K Wireless Receiver, configured through OpenMouse.
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3554", ATTRS{idProduct}=="f509", TAG+="uaccess"
      # EVO75 keyboard, configured through cfg.ticktype.com.
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="36b0", ATTRS{idProduct}=="311e", TAG+="uaccess"
    '')
  ];
}
