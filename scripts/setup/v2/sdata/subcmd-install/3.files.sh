# Config file installation for niri-caelestia-shell
echo -e "${STY_CYAN}Deploying configuration files and building the shell...${STY_RST}"

# 1. Perform Safety Backup
# We backup clashing items from ~/.config before installing dotfiles
echo -e "${STY_BLUE}Running pre-installation backup...${STY_RST}"
# Updated path to dotfiles/.config
backup_clashing_configs "$REPO_ROOT/dotfiles/.config" "$XDG_CONFIG_HOME" "$BACKUP_DIR"

# 2. Ensure Target Directories
mkdir -p "$XDG_CONFIG_HOME/niri"
mkdir -p "$XDG_CONFIG_HOME/quickshell/niri-caelestia-shell"
mkdir -p "$XDG_CONFIG_HOME/Kvantum"
mkdir -p "$XDG_STATE_HOME/quickshell/user/generated/terminal"
mkdir -p "$XDG_STATE_HOME/quickshell/user/generated/wallpaper"
mkdir -p "$HOME/Pictures/Wallpapers"

# 3. Install & Build Shell Code
echo -e "${STY_BLUE}Building and installing shell...${STY_RST}"
TARGET_DIR="$XDG_CONFIG_HOME/quickshell/niri-caelestia-shell"

# Copy local repository files to target directory
cp -rf "$REPO_ROOT"/* "$TARGET_DIR/"

# Move into target directory for the build
cd "$TARGET_DIR"

# Build process
echo -e "  ${STY_DIM}Configuring with CMake (Ninja)...${STY_RST}"
v cmake -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/

echo -e "  ${STY_DIM}Compiling...${STY_RST}"
v cmake --build build

echo -e "  ${STY_DIM}Installing to system...${STY_RST}"
v sudo cmake --install build

# 4. Deploy Dotfiles
echo -e "${STY_BLUE}Deploying dotfiles to ~/.config/...${STY_RST}"
# Updated path to target items inside dotfiles/.config
if [[ -d "$TARGET_DIR/dotfiles/.config" ]]; then
  cp -rf "$TARGET_DIR/dotfiles/.config"/* "$XDG_CONFIG_HOME/"
fi

# 5. Copy Wallpapers
echo -e "${STY_BLUE}Copying wallpapers to ~/Pictures/Wallpapers/...${STY_RST}"
if [[ -d "$TARGET_DIR/images/Wallpapers" ]]; then
  cp -rf "$TARGET_DIR/images/Wallpapers"/* "$HOME/Pictures/Wallpapers/"
fi

# 6. Specialized Font Installer (Google Sans Flex)
install_google_sans_flex(){
  local src_url="https://github.com/end-4/google-sans-flex"
  local target_dir="${XDG_DATA_HOME}/fonts/google-sans-flex"
  if fc-list | grep -qi "Google Sans Flex"; then return; fi
  
  echo -e "${STY_CYAN}Downloading Google Sans Flex...${STY_RST}"
  local tmp=$(mktemp -d)
  git clone --depth 1 "$src_url" "$tmp"
  mkdir -p "$target_dir"
  cp -rf "$tmp"/* "$target_dir/"
  fc-cache -f "$target_dir"
  rm -rf "$tmp"
}
install_google_sans_flex

# Return to the original setup directory
cd - > /dev/null

echo -e "${STY_GREEN}Installation, Build, and Backup complete!${STY_RST}"
