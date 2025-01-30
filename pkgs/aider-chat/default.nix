{
  lib,
  buildPythonPackage,
  fetchPypi,
  setuptools,
  setuptools-scm,
  wheel,
  pip,
  tqdm,
  tree-sitter,
  typing-extensions,
  urllib3,
  watchfiles,
  wcwidth,
  yarl,
  zipp,
  tokenizers,
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
    setuptools-scm
    wheel
  ];

  nativeBuildInputs = [
    setuptools-scm
  ];

  propagatedBuildInputs = [
    (pip.overridePythonAttrs (old: { version = "24.3.1"; }))
    (tqdm.overridePythonAttrs (old: { version = "4.67.1"; }))
    (tree-sitter.overridePythonAttrs (old: { version = "0.21.3"; }))
    (typing-extensions.overridePythonAttrs (old: { version = "4.12.2"; }))
    (urllib3.overridePythonAttrs (old: { version = "2.3.0"; }))
    (watchfiles.overridePythonAttrs (old: { version = "1.0.4"; }))
    wcwidth
    (yarl.overridePythonAttrs (old: { version = "1.18.3"; }))
    (zipp.overridePythonAttrs (old: { version = "3.21.0"; }))
    tokenizers
  ];
}
