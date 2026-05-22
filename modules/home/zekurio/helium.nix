{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.home.helium;
  heliumPkg = inputs.helium.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # ── Extension IDs ────────────────────────────────────────────────
  ublockId = "blockjmkbacgjkknlgpkjjiijinjdanf";
  sponsorblockId = "mnjggcdmjocbbbhaepdhchncahnbgone";
  violentmonkeyId = "jinjaccalgkegednnccohejagnlnfdag";
  onepasswordId = "aeblfdkhhhdcdjpifhhbdiojplfjncoa";

  # ── Extensions to force-install (IDs from Chrome Web Store) ──────
  forceInstallIds = [
    ublockId
    sponsorblockId
    violentmonkeyId
    onepasswordId
  ];

  # ── Managed bookmarks skeleton ───────────────────────────────────
  bookmarks = [
    {
      toplevel_name = "Tools";
    }
  ];

  # ── Chromium policy (applied via /etc/chromium/policies/managed) ─
  policy = {
    ExtensionInstallBlocklist = ["*"];
    ExtensionInstallAllowlist = forceInstallIds;
    ExtensionInstallForcelist = forceInstallIds;
    ExtensionInstallSources = ["https://services.helium.imput.net/*"];

    DefaultBrowserSettingEnabled = false;
    DeveloperToolsAvailability = 1;

    DefaultSearchProviderEnabled = true;
    DefaultSearchProviderName = "Kagi";
    DefaultSearchProviderSearchURL = "https://kagi.com/search?q={searchTerms}";
    DefaultSearchProviderSuggestURL = "https://kagi.com/api/autosuggest?q={searchTerms}";
    SearchSuggestEnabled = true;

    ManagedBookmarks = bookmarks;
    RestoreOnStartup = 1;
  };

  # ── Helium preferences ───────────────────────────────────────────
  preferences = {
    helium.completed_onboarding = true;
    helium.services.user_consented = true;
    helium.browser.layout = 2; # vertical tabs
    helium.browser.rounded_frame = false;
    helium.browser.new_tab_next_to_active = true;
    bookmark_bar.show_on_all_tabs = true;
    bookmark_bar.show_tab_groups = false;
    download.prompt_for_download = true;
  };
in {
  options.home.helium = {
    enable = mkEnableOption "Helium browser with uBlock, SponsorBlock, Kagi, Violentmonkey, 1Password";
  };

  config = mkIf cfg.enable {
    home.packages = [heliumPkg];

    xdg.configFile."helium/Default/Preferences".text = builtins.toJSON preferences;

    xdg.mimeApps.defaultApplications = {
      "application/pdf" = "helium.desktop";
      "text/html" = "helium.desktop";
      "text/xml" = "helium.desktop";
      "x-scheme-handler/http" = "helium.desktop";
      "x-scheme-handler/https" = "helium.desktop";
      "image/gif" = "helium.desktop";
      "image/jpeg" = "helium.desktop";
      "image/png" = "helium.desktop";
      "image/webp" = "helium.desktop";
    };
  };
}
