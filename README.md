

## Bootstrap new Nix home-manager 

1. Install nix via determinate-systems installer
2. Run
`nix build homeConfigurations.<configName>.activationPackage`
3. Install 
`./result/activate`

Note: on WSL had some weird issues, after multiple retries they went away.


Based off https://github.com/ryan4yin/nix-config and https://github.com/Misterio77/nix-starter-configs
