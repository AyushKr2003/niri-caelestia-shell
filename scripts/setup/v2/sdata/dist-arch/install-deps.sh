# Arch Linux dependency installer for niri-caelestia-shell
if ! command -v pacman &>/dev/null; then
  echo -e "${STY_RED}Pacman not found. Aborting...${STY_RST}"; exit 1
fi

# 1. Update system
if [[ "$SKIP_SYSUPDATE" != "true" ]]; then
  v sudo pacman -Syu --noconfirm
fi

# 2. AUR Helper
if ! command -v yay &>/dev/null; then
  echo -e "${STY_YELLOW}yay not found. Installing...${STY_RST}"
  sudo pacman -S --needed --noconfirm base-devel git
  tmpdir=$(mktemp -d)
  git clone https://aur.archlinux.org/yay-bin.git "$tmpdir/yay-bin"
  (cd "$tmpdir/yay-bin" && makepkg -si --noconfirm)
  rm -rf "$tmpdir"
fi

# 3. Official Packages (Including all SDDM and shell requirements)
official_pkgs=(
  # Build & Core
  base-devel cmake clang ninja git bc coreutils curl wget jq ripgrep rsync
  # Niri & Wayland
  niri xdg-desktop-portal xdg-desktop-portal-gnome xdg-desktop-portal-kde xdg-desktop-portal-gtk
  # Shell & Terminal
  kitty fish starship eza
  # Audio & Hardware
  pipewire wireplumber pipewire-pulse pavucontrol-qt playerctl brightnessctl ddcutil geoclue
  # Theming & Fonts
  noto-fonts-emoji papirus-icon-theme breeze fontconfig
  # SDDM & Qt6 Modules (Required by theme)
  sddm qt6-svg qt6-declarative qt6-multimedia-ffmpeg qt6-quickeffectmaker
  # System Tools
  bluedevil gnome-keyring networkmanager networkmanager-qt plasma-nm polkit-kde-agent dolphin upower wtype ydotool
  imagemagick hypridle hyprlock hyprpicker translate-shell libqalculate cliphist
  # Python & App Build Deps
  gtk4 libadwaita libsoup3 libportal-gtk4 gobject-introspection systemsettings tesseract tesseract-data-eng wf-recorder slurp swappy
)

echo -e "${STY_BLUE}Installing system packages...${STY_RST}"
v sudo pacman -S --needed --noconfirm "${official_pkgs[@]}"

# 4. AUR Packages
aur_pkgs=(
  bibata-cursor-theme-bin
  whitesur-icon-theme
  breeze-plus
  matugen
  hyprshot
  uv
  darkly-bin
  adw-gtk-theme-git
  ttf-jetbrains-mono-nerd
  ttf-material-symbols-variable-git
  ttf-readex-pro
  ttf-rubik-vf
  ttf-twemoji
  otf-space-grotesk
  libcava-git
  ttf-material-icons-git
  app2unit
  python-materialyoucolor
)

echo -e "${STY_BLUE}Installing AUR packages...${STY_RST}"
v yay -S --needed --noconfirm "${aur_pkgs[@]}"
