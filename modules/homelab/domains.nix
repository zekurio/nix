{
  config,
  lib,
  ...
}: {
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
    admin = lib.mkOption {
      type = lib.types.str;
      default = "admin.${config.services.homelab.domains.zekurio}";
      defaultText = lib.literalExpression ''"admin.''${config.services.homelab.domains.zekurio}"'';
      description = "Private domain the admin UIs share, each under its own path.";
    };
  };
}
