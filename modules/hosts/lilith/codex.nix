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

      # Use a short alias for the Catppuccin theme ID. This lets the app's six
      # default-theme expressions select it without changing the ASAR length.
      theme_id = re.compile(rb"CATPPUCCIN:`catppuccin`")
      patched, count = theme_id.subn(rb"C:         `catppuccin`", original)
      if count != 3:
          sys.exit(f"expected three Catppuccin theme IDs, found {count}")

      default_theme = re.compile(
          rb"\.CODEX,(?=description:`Code theme used in (?:light|dark) mode`)"
      )
      patched, count = default_theme.subn(rb".C    ,", patched)
      if count != 6:
          sys.exit(f"expected six default code themes, found {count}")

      # The app bundles Frappé but omits it from the small loader table used by
      # color presets. Redirect the unused Mocha entry to the bundled Frappé
      # chunk, including its generated dependency index.
      frappe_chunk = re.compile(
          rb'"catppuccin-frappe":\(\)=>p\(\(\)=>import\(`'
          rb"(?P<path>\./catppuccin-frappe-[a-f0-9]+\.js)`\),"
          rb"(?P<deps>__vite__mapDeps\(\[\d+,1\]\))"
      )
      matches = list(frappe_chunk.finditer(patched))
      if len(matches) != 1:
          sys.exit(f"expected one Frappé chunk, found {len(matches)}")
      frappe_path = matches[0]["path"]
      frappe_deps = matches[0]["deps"]

      mocha_loader = re.compile(
          rb'"catppuccin-mocha"\(\)\{return p\(\(\)=>import\(`'
          rb"\./catppuccin-mocha-[a-f0-9]+\.js`\),"
          rb"__vite__mapDeps\(\[\d+,1\]\)"
      )
      patched, count = mocha_loader.subn(
          lambda _: rb'"catppuccin-frappe"(){return p(()=>import(`'
          + frappe_path
          + rb"`),"
          + frappe_deps,
          patched,
      )
      if count != 1:
          sys.exit(f"expected one Catppuccin Mocha loader, found {count}")

      # The app exposes one Catppuccin preset and hardcodes Mocha for its dark
      # variant.
      preset = re.compile(
          rb"(?P<prefix>[\w$]+\([\w$]+\.CATPPUCCIN,)"
          rb"`Catppuccin`,\{dark:`catppuccin-mocha`,light:`catppuccin-latte`\}\)"
      )
      matches = list(preset.finditer(patched))
      if len(matches) != 1:
          sys.exit(f"expected one Catppuccin preset, found {len(matches)}")

      patched = preset.sub(
          lambda match: match["prefix"]
          + rb"`Catppuccin Frappe`,{dark:`catppuccin-frappe`,light:`catppuccin-latte`})",
          patched,
          count=1,
      )

      theme_reference = re.compile(rb"\.CATPPUCCIN")
      patched, count = theme_reference.subn(rb".C         ", patched)
      if count != 1:
          sys.exit(f"expected one Catppuccin theme reference, found {count}")

      # ASAR stores fixed file offsets. Shorten the now-unused source-map URL
      # by the ten bytes added above so every archived file stays in place.
      source_map = re.compile(
          rb"//# sourceMappingURL=app-"
          rb"initial-(?P<suffix>[A-Za-z0-9_-]+\.js\.map)"
      )
      matches = list(source_map.finditer(patched))
      if len(matches) != 1:
          sys.exit(f"expected one app source map, found {len(matches)}")
      patched = source_map.sub(
          rb"//# sourceMappingURL=ap\g<suffix>", patched, count=1
      )

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
