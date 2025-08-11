# Nix Configurations

A modular NixOS and Home Manager configuration repository supporting multiple systems including NixOS, Darwin (macOS), WSL, and Nix-on-Droid.

## 📁 Repository Structure

```
.
├── flake.nix                 # Main flake configuration
├── hosts/                    # Host-specific configurations
│   ├── driftwood/           # Desktop NixOS system
│   ├── g14/                 # ASUS ROG Zephyrus G14 laptop (Home Manager only)
│   ├── moss/                # NixOS system
│   ├── rainforest/          # macOS (Darwin) system
│   ├── reef/                # NixOS system
│   ├── rhizome/             # NixOS system
│   ├── wsl/                 # Windows Subsystem for Linux
│   └── droid/               # Android (Nix-on-Droid)
├── modules/                  # Reusable modules
│   ├── home-manager/        # Home Manager modules
│   │   ├── core/           # Essential packages and utilities
│   │   ├── development/    # Development tools and languages
│   │   ├── editors/        # Text editors and IDEs
│   │   ├── profiles/       # Pre-configured user profiles
│   │   ├── shells/         # Shell configurations
│   │   └── terminal/       # Terminal emulators and multiplexers
│   └── nixos/              # NixOS system modules
└── overlays/                # Package overlays and modifications
```

## 🚀 Quick Start

### Prerequisites

1. Install Nix using the [Determinate Systems installer](https://github.com/DeterminateSystems/nix-installer):
   ```bash
   curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
   ```

### Home Manager Setup

For standalone Home Manager configurations (non-NixOS systems):

```bash
# Clone the repository
git clone https://github.com/mikeyobrien/nix-configs.git
cd nix-configs

# Build a specific configuration
nix build .#homeConfigurations.g14.activationPackage

# Activate the configuration
./result/activate
```

Or if you have `home-manager` installed:

```bash
home-manager switch --flake .#g14
```

### NixOS Setup

For NixOS systems:

```bash
# Build and switch to a configuration
sudo nixos-rebuild switch --flake .#moss
```

### Darwin (macOS) Setup

For macOS systems with nix-darwin:

```bash
# Build and switch to a configuration
darwin-rebuild switch --flake .#rainforest
```

## 🎨 Modular Architecture

The configuration uses a modular, composable architecture that allows for flexible host configurations.

### Core Principles

1. **Minimal Base**: The base `home.nix` provides only essential packages and a shell
2. **Additive Composition**: Hosts add features on top of the minimal base
3. **Module Namespacing**: All modules are under the `modules.*` namespace
4. **Profile-based Configuration**: Common configurations are grouped into profiles

### Module Categories

#### Core Modules (`modules.core.*`)
- `essential`: Minimal CLI tools (fd, ripgrep, fzf, etc.)
- `commonCli`: Additional CLI utilities (glow, just, cachix, etc.)
- `fonts`: Nerd Fonts configuration
- `packages`: Legacy module for backward compatibility

#### Development Modules (`modules.development.*`)
- `git`: Git configuration with diff tools
- `direnv`: Directory-based environments
- `gpg`: GPG configuration
- `languages`: Programming language tools (Python, Node.js, Rust, etc.)
- `tools`: Development utilities (lazygit, just)
- `uvx`: Python tool installer

#### Editor Modules (`modules.editors.*`)
- `neovim`: Neovim configuration
- `nixvim`: NixVim configuration (placeholder)
- `emacs`: Emacs configuration

#### Shell Modules (`modules.shells.*`)
- `bash`: Bash configuration
- `fish`: Fish shell with plugins
- `prompts`: Starship prompt configuration

#### Terminal Modules (`modules.terminal.*`)
- `alacritty`: Alacritty terminal emulator
- `tmux`: Terminal multiplexer
- `zellij`: Modern terminal workspace

#### Profile Modules (`modules.profiles.*`)
Pre-configured combinations for common use cases:
- `minimal`: Just the essentials
- `cli-developer`: CLI tools for developers
- `desktop-user`: GUI applications and desktop utilities
- `full-developer`: Everything for full-stack development

## 📝 Configuration Examples

### Minimal Configuration
```nix
# hosts/minimal/home.nix
{ user, lib, ... }: {
  imports = [ ../../home-manager/home.nix ];
  
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
  # Inherits only essential packages and fish shell
}
```

### CLI Developer Setup
```nix
# hosts/dev/home.nix
{ user, lib, ... }: {
  imports = [
    ../../home-manager/home.nix
    ../../modules/home-manager/profiles/cli-developer.nix
  ];
  
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
}
```

### Custom Additive Configuration
```nix
# hosts/custom/home.nix
{ user, lib, ... }: {
  imports = [ ../../home-manager/home.nix ];
  
  home = {
    username = user;
    homeDirectory = "/home/${user}";
  };
  
  # Add only what you need
  modules.core.commonCli.enable = true;
  modules.development = {
    git.enable = true;
    direnv.enable = true;
    languages.enable = true;
  };
  modules.terminal.alacritty.enable = true;
  modules.editors.neovim.enable = true;
}
```

### Overriding Defaults
```nix
# Use lib.mkForce to override default values
modules.shells.fish.enable = lib.mkForce false;
modules.shells.bash.enable = true;

# Or customize module options
modules.terminal.alacritty = {
  enable = true;
  fontSize = 14;  # Larger font for HiDPI displays
};
```

## 🛠️ Common Tasks

### Adding a New Host

1. Create a new directory under `hosts/`:
   ```bash
   mkdir hosts/myhost
   ```

2. Create `hosts/myhost/home.nix`:
   ```nix
   { user, lib, ... }: {
     imports = [
       ../../home-manager/home.nix
       # Add profiles or configure modules
     ];
     
     home = {
       username = user;
       homeDirectory = "/home/${user}";
     };
     
     # Host-specific configuration
   }
   ```

3. Add the host to `flake.nix`:
   ```nix
   homeConfigurations = {
     myhost = home-manager.lib.homeManagerConfiguration {
       pkgs = nixpkgs.legacyPackages.x86_64-linux;
       extraSpecialArgs = { inherit inputs outputs; };
       modules = [
         (import ./hosts/myhost/home.nix { 
           user = "yourusername"; 
           lib = nixpkgs.lib; 
         })
       ];
     };
   };
   ```

### Creating a Custom Module

1. Create a new module file:
   ```nix
   # modules/home-manager/mycategory/mymodule.nix
   { config, lib, pkgs, ... }:
   
   with lib;
   let
     cfg = config.modules.mycategory.mymodule;
   in {
     options.modules.mycategory.mymodule = {
       enable = mkEnableOption "my custom module";
       
       someOption = mkOption {
         type = types.str;
         default = "default value";
         description = "Description of the option";
       };
     };
     
     config = mkIf cfg.enable {
       # Module implementation
       home.packages = with pkgs; [ some-package ];
     };
   }
   ```

2. Add it to the appropriate category's `default.nix`

3. Import the category in `modules/home-manager/default.nix`

## 🔧 Troubleshooting

### Common Issues

1. **Experimental features error**:
   ```bash
   # Add experimental features flag
   nix --extra-experimental-features "nix-command flakes" build ...
   ```

2. **File conflicts during activation**:
   ```bash
   # Use backup flag
   home-manager switch --flake .#host -b backup
   ```

3. **Unfree packages error**:
   ```bash
   # Allow unfree packages
   NIXPKGS_ALLOW_UNFREE=1 nix build ... --impure
   ```

### WSL-Specific Notes
- Multiple retries might be needed during initial setup
- Some GUI applications may require additional X11 configuration

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes following the modular structure
4. Test your changes on relevant systems
5. Submit a pull request

## 📚 Resources

- [Nix Manual](https://nixos.org/manual/nix/stable/)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)

## 🙏 Acknowledgments

Based on configurations from:
- [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)
- [Misterio77/nix-starter-configs](https://github.com/Misterio77/nix-starter-configs)

## 📄 License

This repository is available under the MIT License. See LICENSE file for details.