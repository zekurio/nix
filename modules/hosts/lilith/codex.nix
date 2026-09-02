{inputs, ...}: {
  flake.modules.nixos.lilith = {pkgs, ...}: let
    system = pkgs.stdenv.hostPlatform.system;
    chatgptPackage = inputs.llm-agents.packages.${system}.chatgpt;
    themePatch = pkgs.writeText "chatgpt-catppuccin-frappe.py" ''
      import re
      import sys
      from pathlib import Path

      path = Path(sys.argv[1])
      original = path.read_bytes()

      # The app exposes one Catppuccin preset and hardcodes Mocha for its dark
      # variant, despite already bundling the complete Frappé theme.
      preset = re.compile(
          rb"(?P<prefix>[\w$]+\([\w$]+\.CATPPUCCIN,)"
          rb"`Catppuccin`,\{dark:`catppuccin-mocha`,light:`catppuccin-latte`\}\)"
      )
      matches = list(preset.finditer(original))
      if len(matches) != 1:
          sys.exit(f"expected one Catppuccin preset, found {len(matches)}")

      patched = preset.sub(
          lambda match: match["prefix"]
          + rb"`Catppuccin Frappe`,{dark:`catppuccin-frappe`,light:`catppuccin-latte`})",
          original,
          count=1,
      )

      # ASAR stores fixed file offsets. Shorten the now-unused source-map URL
      # by the eight bytes added above so every archived file stays in place.
      source_map = re.compile(
          rb"(?P<prefix>//# sourceMappingURL=app-)"
          rb"initial-(?P<suffix>[A-Za-z0-9_-]+\.js\.map)"
      )
      matches = list(source_map.finditer(patched))
      if len(matches) != 1:
          sys.exit(f"expected one app source map, found {len(matches)}")
      patched = source_map.sub(rb"\g<prefix>\g<suffix>", patched, count=1)

      if len(patched) != len(original):
          sys.exit("theme patch changed the ASAR length")
      path.write_bytes(patched)
    '';
    chatgptUnwrapped = chatgptPackage.unwrapped.overrideAttrs (oldAttrs: {
      postFixup =
        (oldAttrs.postFixup or "")
        + ''
          ${pkgs.python3}/bin/python3 ${themePatch} \
            "$out/lib/chatgpt/resources/app.asar"
        '';
    });
    chatgpt = chatgptPackage.override {
      chatgpt-unwrapped = chatgptUnwrapped;
    };
  in {
    environment.systemPackages = [chatgpt];
  };
}
