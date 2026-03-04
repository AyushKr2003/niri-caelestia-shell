#!/usr/bin/env bash

# materialQT.sh — Apply Material You colors to Kvantum Qt theme
#
# Requires: Colloid-kde theme installed at ~/.config/Kvantum/Colloid/
# Reads colors from: ~/.local/state/quickshell/user/generated/material_colors.scss
# Outputs to: ~/.config/Kvantum/MaterialAdw/

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../_env.sh"

KVANTUM_SCRIPT_DIR="$SCRIPT_DIR/kvantum"

get_light_dark() {
	local current_mode
	current_mode=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
	if [[ "$current_mode" == "prefer-dark" ]]; then
		echo "dark"
	else
		echo "light"
	fi
}

apply_qt() {
	local folder_path="$XDG_CONFIG_HOME/Kvantum/Colloid"
	local output_dir="$XDG_CONFIG_HOME/Kvantum/MaterialAdw"

	if [[ ! -d "$folder_path" ]]; then
		log "Kvantum Colloid theme not found at '$folder_path', skipping Qt theming"
		return 0
	fi

	mkdir -p "$output_dir"

	local lightdark
	lightdark=$(get_light_dark)

	if [[ "$lightdark" == "light" ]]; then
		cp "$folder_path/Colloid.kvconfig" "$output_dir/MaterialAdw.kvconfig"
		python "$KVANTUM_SCRIPT_DIR/adwsvg.py"
	else
		cp "$folder_path/ColloidDark.kvconfig" "$output_dir/MaterialAdw.kvconfig"
		python "$KVANTUM_SCRIPT_DIR/adwsvgDark.py"
	fi

	# Update kvconfig colors from SCSS
	python "$KVANTUM_SCRIPT_DIR/changeAdwColors.py"

	log "Kvantum MaterialAdw theme updated"
}

apply_qt
