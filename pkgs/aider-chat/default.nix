{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  wheel,
}:

buildPythonPackage rec {
  pname = "aider-chat";
  version = "0.72.3";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-OuUhORfFF0SmlnjgcWQJTOISPq3Uy4RCq4QB6UUIC/0=";
  };

  # do not run tests
  doCheck = false;

  # specific to buildPythonPackage, see its reference
  pyproject = true;
  build-system = [
    setuptools
    wheel
  ];
}
