{
  lib,
  python311Packages,
  fetchFromGitHub,
}:
python311Packages.buildPythonPackage rec {
  pname = "lgtv";
  version = "0.1.2";

  src = fetchFromGitHub {
    owner = "klattimer";
    repo = "LGWebOsRemote";
    rev = "616b35da0d939dbb9171d89ac6024e3fd9b85e2b";
    hash = "sha256-bNcD7vWQYrgwRrV3cmHaE9h44NNJonX0EeSYvHc/5N4=";
  };

  nativeBuildInputs = with python311Packages; [
    pip
  ];

  propagatedBuildInputs = with python311Packages; [
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
