{
  flake.modules.nixos.homelab = {
    config,
    lib,
    pkgs,
    ...
  }: let
    patched = name: path: hash: patch:
      pkgs.runCommand "kyoo-${name}-folder-ids" {
        src = pkgs.fetchurl {
          url = "https://raw.githubusercontent.com/zoriya/kyoo/v5.2.1/scanner/scanner/${path}";
          inherit hash;
        };
        nativeBuildInputs = [pkgs.patch];
      } ''
        cp "$src" ${name}.py
        chmod u+w ${name}.py
        patch -p1 < ${patch}
        cp ${name}.py "$out"
      '';
    identify = patched "identify" "identifiers/identify.py" "sha256-4BSi0RbawdcdpuIU2i0/KUmEkkqAqEJU4kfHkNlZKUY=" ./identify-folder-ids.patch;
    fsscan = patched "fsscan" "fsscan.py" "sha256-pkAIgbcjqjOYPXQzpjjdtdoNs5Y9DZZwlLpX4hte168=" ./fsscan-folder-ids.patch;
  in {
    config = lib.mkIf config.services.homelab.kyoo.enable {
      virtualisation.oci-containers.containers.kyoo-scanner.volumes = [
        "${identify}:/app/scanner/identifiers/identify.py:ro"
        "${./folder-ids.py}:/app/scanner/identifiers/folder_ids.py:ro"
        "${fsscan}:/app/scanner/fsscan.py:ro"
      ];
    };
  };
}
