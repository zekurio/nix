{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    kdePackages.libkscreen
  ];

  systemd.user.services.refresh-rate-monitor = {
    description = "Auto-switch display refresh rate on power change";
    wantedBy = ["graphical-session.target"];
    partOf = ["graphical-session.target"];
    path = with pkgs; [
      kdePackages.libkscreen
      upower
    ];
    script = ''
      on_ac() {
        kscreen-doctor output.eDP-1.mode.1920x1080@120.00
      }

      on_bat() {
        kscreen-doctor output.eDP-1.mode.1920x1080@60.00
      }

      power_status() {
        while IFS= read -r line; do
          case "$line" in
            *"online:"*)
              set -- $line
              printf '%s\n' "$2"
              return 0
              ;;
          esac
        done < <(upower -i /org/freedesktop/UPower/devices/line_power_AC)

        return 1
      }

      apply_refresh_rate() {
        if [ "$(power_status)" = "yes" ]; then
          on_ac
        else
          on_bat
        fi
      }

      apply_refresh_rate

      upower --monitor | while IFS= read -r line; do
        case "$line" in
          *line_power*)
            apply_refresh_rate
            ;;
        esac
      done
    '';
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "3s";
    };
  };
}
