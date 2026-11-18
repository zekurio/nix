{
  runCommand,
  writeText,
  # The hdr-mode script, from the HDR module.
  settings,
}: let
  config = writeText "Config.js" ''
    .pragma library
    var config = ${builtins.toJSON settings};
  '';
in
  runCommand "dux-hdr-toggle" {} ''
    cp -r ${./_dux-plugin} $out
    chmod u+w $out
    cp ${config} $out/Config.js
  ''
