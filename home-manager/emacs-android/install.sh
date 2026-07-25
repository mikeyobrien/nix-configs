#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

source_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
config_dir=${EMACS_CONFIG_DIR:-"$HOME/.emacs.d"}
android_emacs_files=${ANDROID_EMACS_FILES:-/data/data/org.gnu.emacs/files}
android_config="$android_emacs_files/.emacs.d"
font_dir="$android_emacs_files/fonts"

mkdir -p "$config_dir" "$font_dir"
for file in init.el early-init.el README.md .gitignore; do
  install -m 600 "$source_dir/$file" "$config_dir/$file"
done

install_font() {
  local filename=$1
  local sha256=$2
  local url=$3
  local destination="$font_dir/$filename"

  if [[ -f "$destination" ]] && printf '%s  %s\n' "$sha256" "$destination" | sha256sum -c - >/dev/null 2>&1; then
    return
  fi

  local temporary
  temporary=$(mktemp "${TMPDIR:-$PREFIX/tmp}/emacs-font.XXXXXX")
  trap 'rm -f "$temporary"' RETURN
  curl --fail --location --retry 2 --output "$temporary" "$url"
  printf '%s  %s\n' "$sha256" "$temporary" | sha256sum -c -
  install -m 600 "$temporary" "$destination"
  rm -f "$temporary"
  trap - RETURN
}

install_font \
  NotoSansSymbols2-Regular.ttf \
  630846d528dbe4c4981370a4d0a9475a1fd1491a129bb411f8e157cdb5de13c6 \
  https://raw.githubusercontent.com/notofonts/noto-fonts/be555adc61c20b2240bce79203b1ab1459765171/hinted/ttf/NotoSansSymbols2/NotoSansSymbols2-Regular.ttf

install_font \
  NotoEmoji-Regular.ttf \
  415dc6290378574135b64c808dc640c1df7531973290c4970c51fdeb849cb0c5 \
  https://raw.githubusercontent.com/googlefonts/noto-emoji/2f1ffdd6fbbd05d6f382138a3d3adcd89c5ce800/fonts/NotoEmoji-Regular.ttf

if [[ -L "$android_config" ]]; then
  current_target=$(readlink -f "$android_config")
  expected_target=$(readlink -f "$config_dir")
  if [[ "$current_target" != "$expected_target" ]]; then
    printf 'Refusing to replace %s -> %s\n' "$android_config" "$current_target" >&2
    exit 1
  fi
elif [[ -e "$android_config" ]]; then
  backup="${android_config}.pre-dotfiles.$(date +%Y%m%d-%H%M%S)"
  mv "$android_config" "$backup"
  printf 'Preserved previous Android Emacs state at %s\n' "$backup"
  ln -s "$config_dir" "$android_config"
else
  ln -s "$config_dir" "$android_config"
fi

if [[ ! -e "$config_dir/local.el" ]]; then
  install -m 600 "$source_dir/local.el.example" "$config_dir/local.el.example"
  printf 'Configure private paths in %s/local.el\n' "$config_dir"
fi

printf 'Android Emacs configuration installed. Restart Emacs to apply it.\n'
