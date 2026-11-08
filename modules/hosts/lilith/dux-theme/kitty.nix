{lib, ...}: {
  home-manager.users.zekurio.programs.kitty = {
    # Dux writes both files on every theme change and signals kitty to
    # reload them. Including them ahead of the settings, which home-manager
    # writes at order 540, lets the shared flat tabs override the powerline
    # layout in dank-tabs.conf so only its colours stay.
    extraConfig = lib.mkOrder 520 ''
      include dank-tabs.conf
      include dank-theme.conf
    '';
    # dank-tabs.conf sets its own title for the active tab.
    settings.active_tab_title_template = "none";
  };
}
