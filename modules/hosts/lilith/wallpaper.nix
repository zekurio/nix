{pkgs, ...}: let
  # Plasma's wallpaper pickers save the resolved /nix/store path. Once a
  # Plasma update replaces the package and the weekly GC deletes the old one,
  # the lock screen and desktop silently fall back to the default wallpaper.
  # Declaring it rewrites the path to the current package on every activation.
  wallpaper = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Mountain";
in {
  home-manager.users.zekurio.programs.plasma = {
    workspace.wallpaper = wallpaper;
    kscreenlocker.appearance.wallpaper = wallpaper;
  };
}
