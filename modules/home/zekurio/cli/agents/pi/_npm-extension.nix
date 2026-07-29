{
  fetchurl,
  lib,
  stdenvNoCC,
}:
# Pi extensions published to npm are plain TypeScript that Pi's bundled runtime
# loads directly: the packages we use declare no runtime dependencies, only a
# peer dependency on Pi itself. Unpacking the published tarball is therefore the
# whole build, and it keeps a global npm or bun out of the picture.
{
  pname,
  version,
  hash,
  # Scoped names ("@scope/name") do not appear in the tarball URL path the same
  # way, so the registry path is derived rather than assumed.
  npmName ? pname,
}:
stdenvNoCC.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://registry.npmjs.org/${npmName}/-/${lib.last (lib.splitString "/" npmName)}-${version}.tgz";
    inherit hash;
  };

  # The tarball's single top-level "package" directory becomes the extension
  # directory, so package.json (and its "pi.extensions" entry point) is kept.
  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r . "$out/"
    runHook postInstall
  '';

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  meta = {
    description = "Pi extension ${npmName}";
    homepage = "https://www.npmjs.com/package/${npmName}";
    license = lib.licenses.mit;
  };
}
