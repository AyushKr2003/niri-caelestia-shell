pragma Singleton

import qs.config
import Quickshell
import Quickshell.Io
import QtQuick

// Common Material Symbols icons for the picker
Singleton {
    id: root

    // Commonly used Material Symbols icons organized by category
    readonly property var iconCategories: ({
        "Actions": [
            "add", "remove", "delete", "edit", "save", "close", "check", "clear",
            "search", "refresh", "settings", "more_vert", "more_horiz", "menu",
            "arrow_back", "arrow_forward", "expand_more", "expand_less",
            "chevron_left", "chevron_right", "open_in_new", "launch", "download",
            "upload", "share", "copy", "content_copy", "content_paste", "undo", "redo"
        ],
        "Alerts": [
            "warning", "error", "info", "help", "notification_important",
            "priority_high", "report", "dangerous", "error_outline", "warning_amber"
        ],
        "Battery": [
            "battery_full", "battery_6_bar", "battery_5_bar", "battery_4_bar",
            "battery_3_bar", "battery_2_bar", "battery_1_bar", "battery_0_bar",
            "battery_alert", "battery_charging_full", "battery_saver",
            "battery_unknown", "battery_std", "battery_plus", "charging_station"
        ],
        "Communication": [
            "email", "mail", "message", "chat", "forum", "comment", "feedback",
            "call", "phone", "contacts", "person", "people", "group", "notifications",
            "notifications_active", "notifications_off", "mark_email_read"
        ],
        "Content": [
            "folder", "folder_open", "file_copy", "description", "article",
            "note", "bookmark", "label", "flag", "star", "favorite", "thumb_up",
            "thumb_down", "visibility", "visibility_off", "lock", "lock_open"
        ],
        "Device": [
            "computer", "laptop", "desktop_windows", "phone_android", "tablet",
            "watch", "headphones", "speaker", "mic", "mic_off", "videocam",
            "camera", "bluetooth", "wifi", "signal_cellular_4_bar", "brightness_high",
            "brightness_low", "brightness_medium", "dark_mode", "light_mode"
        ],
        "Editor": [
            "format_bold", "format_italic", "format_underlined", "format_list_bulleted",
            "format_list_numbered", "format_align_left", "format_align_center",
            "format_align_right", "format_color_fill", "format_color_text"
        ],
        "Files": [
            "attachment", "cloud", "cloud_upload", "cloud_download", "cloud_sync",
            "storage", "sd_card", "usb", "save_alt", "file_present", "file_open"
        ],
        "Hardware": [
            "memory", "developer_board", "keyboard", "mouse", "power",
            "power_settings_new", "electrical_services", "bolt"
        ],
        "Media": [
            "play_arrow", "pause", "stop", "skip_next", "skip_previous",
            "fast_forward", "fast_rewind", "replay", "shuffle", "repeat",
            "volume_up", "volume_down", "volume_mute", "volume_off",
            "music_note", "album", "movie", "image", "photo_library", "slideshow"
        ],
        "Navigation": [
            "home", "menu", "apps", "dashboard", "view_list", "view_module",
            "view_quilt", "grid_view", "list", "table_chart", "timeline",
            "fullscreen", "fullscreen_exit", "zoom_in", "zoom_out"
        ],
        "Social": [
            "person", "person_add", "person_remove", "group", "group_add",
            "public", "share", "thumb_up", "thumb_down", "mood", "sentiment_satisfied"
        ],
        "System": [
            "settings", "tune", "build", "extension", "widgets", "code",
            "terminal", "bug_report", "security", "admin_panel_settings",
            "manage_accounts", "account_circle", "logout", "login", "cached",
            "sync", "update", "schedule", "access_time", "timer", "hourglass_empty"
        ],
        "Toggle": [
            "toggle_on", "toggle_off", "check_box", "check_box_outline_blank",
            "radio_button_checked", "radio_button_unchecked", "indeterminate_check_box"
        ],
        "Weather": [
            "wb_sunny", "nights_stay", "cloud", "cloud_queue", "thunderstorm",
            "water_drop", "ac_unit", "thermostat", "air", "waves"
        ]
    })

    // Flat list of all icons for searching
    readonly property var allIcons: {
        let icons = [];
        for (const category in iconCategories) {
            icons = icons.concat(iconCategories[category]);
        }
        return icons;
    }

    function searchIcons(query: string): var {
        if (!query || query.trim() === "") {
            return allIcons.slice(0, 50); // Return first 50 when no search
        }
        const lowerQuery = query.toLowerCase();
        return allIcons.filter(icon => icon.toLowerCase().includes(lowerQuery));
    }

    function getIconsByCategory(category: string): var {
        return iconCategories[category] || [];
    }

    readonly property var categoryNames: Object.keys(iconCategories)
}
