let
  # Nixpkgs now signs modules with kmodigest during modules_install, and the
  # modules tree concatenates each external module's .ko.cer. zenpower and
  # ryzen-smu copy their .ko by hand, so the tree build fails on the missing
  # certificates. NixOS/nixpkgs@976984a and @ce387ef fix this upstream by
  # switching to modules_install, which ships signed .ko.xz files this find
  # ignores. Drop the file once both reach nixos-unstable.
  overlay = final: previous: {
    kernelPackagesExtensions =
      previous.kernelPackagesExtensions
      ++ [
        (_kernelFinal: kernelPrevious: let
          sign = package:
            package.overrideAttrs (old: {
              # Sign after fixup: stripping an uncompressed module drops the
              # appended signature, which modules_install avoids by compressing.
              postFixup =
                (old.postFixup or "")
                + ''
                  find "$out/lib/modules" -name '*.ko' \
                    -exec ${final.lib.getExe final.buildPackages.kmodigest} {} \;
                '';
            });
        in {
          zenpower = sign kernelPrevious.zenpower;
          ryzen-smu = sign kernelPrevious.ryzen-smu;
        })
      ];
  };
in {
  nixpkgs.overlays = [overlay];
}
