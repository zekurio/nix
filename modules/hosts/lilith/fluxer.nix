{
  inputs,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    # With module updates off, the client cannot download spellcheck
    # dictionaries itself.
    (inputs.fluxer-nix.packages.${pkgs.stdenv.hostPlatform.system}.fluxer-desktop.override {
      hunspellDictionaries = with pkgs.hunspellDicts; [de_AT en_US];
    })
  ];
}
