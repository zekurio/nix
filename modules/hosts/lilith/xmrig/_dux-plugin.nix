{
  runCommand,
  writeText,
  # Ports, scripts and the address, from the miner module.
  settings,
}: let
  config = writeText "Config.js" ''
    .pragma library
    var config = ${builtins.toJSON settings};
  '';
in
  runCommand "dux-xmrig-control" {} ''
    cp -r ${./_dux-plugin} $out
    chmod u+w $out
    cp ${config} $out/Config.js
  ''
