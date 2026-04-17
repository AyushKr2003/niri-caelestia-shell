# Common functions for niri-caelestia-shell installer
function try { "$@" || sleep 0; }
function v(){
  echo -e "${STY_CYAN}[next]: $*${STY_RST}"
  local execute=true
  if $ask; then
    read -p "Execute? [Y/n/s/all]: " p
    case $p in
      [nNsS]) execute=false ;;
      "all") ask=false ;;
      *) execute=true ;;
    esac
  fi
  if $execute; then x "$@"; fi
}
function x(){
  if "$@"; then return 0; else
    echo -e "${STY_RED}Failed: $*${STY_RST}"
    read -p "[R]etry, [i]gnore, [e]xit: " p
    case $p in
      [iI]) return 0 ;;
      [eE]) exit 1 ;;
      *) x "$@" ;;
    esac
  fi
}
function showfun() {
  echo -e "${STY_BLUE}The definition of function \"$1\" is as follows:${STY_RST}"
  echo -e "${STY_GREEN}"
  type -a "$1"
  echo -e "${STY_RST}"
}
function pause(){
  if [[ "$ask" != "false" ]]; then
    read -p "(Enter to continue, Ctrl-C to abort)"
  fi
}
function prevent_sudo_or_root(){
  if [[ $EUID -eq 0 ]]; then
    echo -e "${STY_RED}Do not run as root.${STY_RST}"; exit 1
  fi
}
declare -g SUDO_KEEPALIVE_PID=""
function sudo_init_keepalive(){
  sudo -v
  ( while true; do sudo -n true; sleep 60; done ) &
  SUDO_KEEPALIVE_PID=$!
}
function sudo_stop_keepalive(){
  [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
}

# Smart Backup Function: Preserves existing files that clash with the new ones
function backup_clashing_configs(){
  local source_dir="$1"
  local target_dir="$2"
  local backup_path="$3"
  
  if [[ ! -d "$source_dir" ]]; then return 0; fi
  
  echo -e "${STY_BLUE}Checking for clashing configs in $(basename "$target_dir")...${STY_RST}"
  
  # Create a timestamped subfolder for this backup session
  local session_backup="${backup_path}/$(date +%Y%m%d_%H%M%S)"
  local clash_found=false

  # Find top-level items in the source folder
  for item in $(ls -A "$source_dir"); do
    if [[ -e "${target_dir}/${item}" ]]; then
      if ! $clash_found; then
        mkdir -p "$session_backup"
        clash_found=true
      fi
      echo -e "  ${STY_DIM}Preserving: $item${STY_RST}"
      cp -rf "${target_dir}/${item}" "${session_backup}/"
    fi
  done

  if $clash_found; then
    echo -e "${STY_GREEN}Backup saved to: $session_backup${STY_RST}"
  fi
}
