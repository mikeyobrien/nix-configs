{
  lib,
  pkgs,
  python3Packages,
  fetchFromGitHub,
  fetchurl,
}:
python3Packages.buildPythonPackage rec {
  pname = "lgtv";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "klattimer";
    repo = "LGWebOsRemote";
    rev = "183935b51c4885fcb1b08c9e4a18bbd261308c93";
    hash = "sha256-uknbRRRIVqZ9OVmv7HgQwqOFRf1STWNbGLRpjLFX+Ek=";
  };

  nativeBuildInputs = with python3Packages; [
    pip
  ];

  propagatedBuildInputs = with python3Packages; [
    wakeonlan
    ws4py
    requests
    getmac
  ];

  meta = with lib; {
    description = "A Python-based remote control for LG WebOS TVs";
    homepage = "https://github.com/klattimer/LGWebOSRemote";
    license = licenses.gpl3;
    maintainers = [maintainers.mikeyobrien];
  };
}
