{
  config,
  lib,
  ...
}:
let
  shareUser = "share";
  shareGroup = "share";
  domain = "nzb.schnitzelflix.xyz";
  port = 6789;
in
{
  options.services.nzbget-wrapped = {
    enable = lib.mkEnableOption "NZBGet Usenet downloader with Caddy integration";
  };

  config = lib.mkIf config.services.nzbget-wrapped.enable {
    services.nzbget = {
      enable = true;
      user = shareUser;
      group = shareGroup;
    };

    services.caddy-wrapper.virtualHosts."nzbget" = {
      inherit domain;
      reverseProxy = "127.0.0.1:${toString port}";
    };
  };
}
