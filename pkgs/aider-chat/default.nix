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
    inherit version;
    pname = "aider_chat";
    hash = "sha256-XwtN1g5dz41M8jpP1wn6wfUjorqgEk8fClUY0t/FnbA=";
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
