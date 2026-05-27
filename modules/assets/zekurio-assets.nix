{
  imagemagick,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation {
  pname = "zekurio-assets";
  version = "1";

  src = ../../assets/images;

  nativeBuildInputs = [
    imagemagick
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/zekurio/assets
    cp -r $src/. $out/share/zekurio/assets/

    mkdir -p $out/share/wallpapers

    while IFS= read -r image; do
      fileName="$(basename "$image")"
      name="''${fileName%.*}"
      ext="''${fileName##*.}"
      slug="$(printf '%s-%s' "$name" "$ext" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9._-]/-/g')"
      size="$(magick identify -format '%wx%h' "$image[0]")"
      packageDir="$out/share/wallpapers/zekurio-$slug"

      case "$fileName" in
        asuka-you-can-not-redo.png) prettyName="Asuka (3.33)" ;;
        asuka-you-can-not-advance.png) prettyName="Asuka (2.22)" ;;
        cyberpunk-catppuccin.png) prettyName="Cyberpunk Catppuccin" ;;
        night-city-at-night.png) prettyName="Night City at Night" ;;
        night-city.png) prettyName="Night City" ;;
        the-monster-you-created.png) prettyName="The Monster You Created" ;;
        frierens-death-stare.jpg) prettyName="Frieren's Death Stare" ;;
        an-elf-at-rest.png) prettyName="An Elf at Rest" ;;
        windblown-resolve.jpg) prettyName="Windblown Resolve" ;;
        luminous-mushroom.png) prettyName="Luminous Mushroom" ;;
        powders-gaze.png) prettyName="Powder's Graze" ;;
        kusanagis-bike.jpg) prettyName="Kusanagi's Bike" ;;
        major-at-rest.jpg) prettyName="Major at Rest" ;;
        lambs-mask.png) prettyName="Lamb's Mask" ;;
        rei-thrice-upon-a-time.png) prettyName="Rei (3.0 + 1.0)" ;;
        bomb-devil.jpg) prettyName="Bomb Devil" ;;
        broke-ryo.png) prettyName="Broke Ryo" ;;
        *) prettyName="$name ($ext)" ;;
      esac

      mkdir -p "$packageDir/contents/images"
      cp "$image" "$packageDir/contents/images/$size.$ext"
      cp "$image" "$packageDir/contents/screenshot.$ext"

      cat > "$packageDir/metadata.json" <<EOF
    {
      "KPlugin": {
        "Authors": [
          {
            "Name": "Unbekannt"
          }
        ],
        "Id": "zekurio.$slug",
        "License": "LicenseRef-Proprietary",
        "Name": "$prettyName"
      }
    }
    EOF
    done < <(find $src/wallpapers -maxdepth 1 -type f | sort)

    runHook postInstall
  '';

  meta = {
    description = "Personal face icon and Plasma wallpaper assets for Zekurio systems";
  };
}
