{
  flake.modules.nixos.homelab = {lib, ...}: {
    options.services.homelab.domains = {
      zekurio = lib.mkOption {
        type = lib.types.str;
        default = "zekurio.me";
        description = "Base domain for personal services.";
      };
      schnitzelflix = lib.mkOption {
        type = lib.types.str;
        default = "schnitzelflix.xyz";
        description = "Base domain for media services.";
      };
    };
  };
}
