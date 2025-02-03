{ lib, ... }:
pkgs: source:
let
  pname = builtins.head source.name;
  app-artifact = builtins.head (
    builtins.filter (artifact: lib.hasAttr "app" artifact) source.artifacts
  );
  app-name = builtins.head (app-artifact.app);
in
pkgs.stdenv.mkDerivation {
  inherit (source) version;
  inherit pname;

  buildInputs = with pkgs; [ unzip ];
  sourceRoot = ".";
  phases = [
    "unpackPhase"
    "installPhase"
  ];

  unpackCmd = ''

    echo "Creating temp directory"
    mnt=$(TMPDIR=/tmp mktemp -d -t nix-XXXXXXXXXX)
    function finish {
      echo "Ejecting temp directory"
      rm -rf $mnt
    }
    # Detach volume when receiving SIG "0"
    trap finish EXIT

    case "$curSrc" in
      *.dmg)
        echo "Creating temp directory"
        mnt=$(TMPDIR=/tmp mktemp -d -t nix-XXXXXXXXXX)
        function finish {
          echo "Ejecting temp directory"
          /usr/bin/hdiutil detach $mnt -force
          rm -rf $mnt
        }
        # Detach volume when receiving SIG "0"
        trap finish EXIT
        # Mount DMG file
        echo "Mounting DMG file into \"$mnt\""
        /usr/bin/hdiutil attach -nobrowse -mountpoint $mnt $curSrc
        # Copy content to local dir for later use
        echo 'Copying extracted content into "sourceRoot"'
        cp -a "$mnt/${app-name}" $PWD/
        ;;
      *.zip)

        unzip "$curSrc" -d "$mnt";
        # Copy content to local dir for later use
        echo 'Copying extracted content into "sourceRoot"'
        cp -a "$mnt/${app-name}" $PWD/
        ;;
      *)
        _defaultUnpack "$curSrc"
        ;;
    esac


  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/Applications
    cp -r "${lib.lists.last (lib.strings.splitString "/" app-name)}" "$out/Applications/"

    runHook postInstall
  '';

  src = pkgs.fetchurl {
    name = lib.lists.last (lib.strings.splitString "/" source.url);
    inherit (source) url sha256;
  };

  meta = {
    description = source.desc;
    homepage = source.homepage;
  };
}
