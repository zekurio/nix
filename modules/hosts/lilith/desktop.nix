{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: {
    # Ghostty and PDFCraft cover the terminal and PDF reader.
    environment.cosmic.excludePackages = with pkgs; [
      cosmic-reader
      cosmic-term
    ];
    services = {
      desktopManager.cosmic.enable = true;
      displayManager = {
        defaultSession = "cosmic";
        cosmic-greeter.enable = true;
      };
      printing.enable = true;
    };

    home-manager.users.zekurio = {
      imports = [inputs.cosmic-manager.homeManagerModules.cosmic-manager];
      # resetFiles stays off, so settings this flake leaves undeclared remain
      # editable in COSMIC Settings.
      wayland.desktopManager.cosmic.enable = true;
    };
  };
}
