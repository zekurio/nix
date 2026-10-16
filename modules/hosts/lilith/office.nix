{
  flake.modules.nixos.lilith = {pkgs, ...}: let
    craftApp = args: pkgs.callPackage ./_craft-app.nix args;
  in {
    # ArtCraft's clean-room Office and Acrobat counterparts, from upstream's
    # release binaries. nixpkgs packages WordCraft but trails its releases.
    environment.systemPackages = [
      (craftApp {
        pname = "wordcraft";
        version = "0.7.0";
        hash = "sha256-YwCfiOPbrqcKwTePq8hVWuFHddMoKRdcXaJVGr4Dky8=";
        description = "Word processor with DOCX, ODT and RTF support";
      })
      (craftApp {
        pname = "gridcraft";
        version = "0.7.0";
        hash = "sha256-wBvC3EKVVW9TgQ3+1KhaP1g4hVLBV6ED4QYmwGmznhw=";
        description = "Spreadsheet editor with XLSX support";
      })
      (craftApp {
        pname = "deckcraft";
        version = "0.7.0";
        hash = "sha256-Mwovsu+IkNre2RCE5b/SnfpBHjOisnwBrDueUg/5jZ8=";
        description = "Presentation editor with PPTX support";
      })
      (craftApp {
        pname = "pdfcraft";
        version = "0.8.0";
        hash = "sha256-P0/V3dmYAqPTSUdMYc89q9H7cZjqDfANJMwxBRa9HCo=";
        description = "PDF reader and editor";
      })
    ];

    # Office documents name Microsoft fonts. Carlito and Caladea are metric
    # compatible with Calibri and Cambria, so layouts keep their line breaks.
    fonts.packages = with pkgs; [
      corefonts
      carlito
      caladea
      liberation_ttf
    ];
  };
}
