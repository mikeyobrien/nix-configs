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
  soundfile,
  soupsieve,
  tiktoken,
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
    (pip.overrideAttrs (old: { version = "24.3.1"; }))
    (tqdm.overrideAttrs (old: { version = "4.67.1"; }))
    (tree-sitter.overrideAttrs (old: { version = "0.21.3"; }))
    (typing-extensions.overrideAttrs (old: { version = "4.12.2"; }))
    (urllib3.overrideAttrs (old: { version = "2.3.0"; }))
    (watchfiles.overrideAttrs (old: { version = "1.0.4"; }))
    wcwidth
    (yarl.overrideAttrs (old: { version = "1.18.3"; }))
    (zipp.overrideAttrs (old: { version = "3.21.0"; }))
    tokenizers
    soundfile
    soupsieve
    tiktoken
  ];
}
