{ lib
, appimageTools
, fetchurl
, makeWrapper
, stdenv
}:

let
  pname = "amazon-q";
  version = "latest"; # You can replace with specific version if needed
  name = "${pname}-${version}";

  src = fetchurl {
    url = "https://desktop-release.q.us-east-1.amazonaws.com/latest/amazon-q.appimage";
    # Replace with actual hash after downloading once
    # You can get this by running:
    # nix-prefetch-url https://desktop-release.q.us-east-1.amazonaws.com/latest/amazon-q.appimage
    sha256 = "1s24bk9qrphpj8f71qjqc662g7dj9rx4lrl8c2khznkyn01p42zj";
  };

  appimageContents = appimageTools.extractType2 { inherit name src; };
in
appimageTools.wrapType2 {
  inherit name src;

  extraInstallCommands = ''
    install -m 444 -D ${appimageContents}/amazon-q.desktop $out/share/applications/amazon-q.desktop
    install -m 444 -D ${appimageContents}/amazon-q.png $out/share/icons/hicolor/512x512/apps/amazon-q.png
    substituteInPlace $out/share/applications/amazon-q.desktop \
      --replace 'Exec=AppRun' 'Exec=${pname}'
  '';

  meta = with lib; {
    description = "Amazon Q Developer CLI for command line";
    homepage = "https://aws.amazon.com/q/";
    license = licenses.unfree;
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
