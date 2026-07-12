#!/usr/bin/env bash
# design.sh — Multimedia & Design (handbrake moved here from Media Players)

_cat_design() {
    local headless=false
    _is_headless && headless=true
    local -a items=()
    if ! $headless; then
        local audacity_state;  audacity_state=$(_state "audacity")
        local ardour_state;    ardour_state=$(_state "ardour")
        local blender_state;   blender_state=$(_state "blender")
        local gimp_state;      gimp_state=$(_state "gimp")
        local handbrake_state; handbrake_state=$(_state "handbrake")
        local inkscape_state;  inkscape_state=$(_state "inkscape")
        local kdenlive_state;  kdenlive_state=$(_state "kdenlive")
        local krita_state;     krita_state=$(_state "krita")
        local obs_state;       obs_state=$(_state "obs-studio")
        local openshot_state;  openshot_state=$(_state "openshot-qt")
        local scribus_state;   scribus_state=$(_state "scribus")
        local shotcut_state;   shotcut_state=$(_state "shotcut")
        items+=(
            "audacity"     "Audio editor/recorder"      "$audacity_state"
            "ardour"       "Digital audio workstation"        "$ardour_state"
            "blender"      "3D modeling/animation"       "$blender_state"
            "gimp"         "Image editor"          "$gimp_state"
            "handbrake"    "Video transcoder"     "$handbrake_state"
            "inkscape"     "Vector graphics editor"      "$inkscape_state"
            "kdenlive"     "Video editor (KDE)"      "$kdenlive_state"
            "krita"        "Digital painting"         "$krita_state"
            "obs-studio"   "Screen recording"   "$obs_state"
            "openshot-qt"  "Simple video editor"   "$openshot_state"
            "scribus"      "Desktop publishing"       "$scribus_state"
            "shotcut"      "Cross-platform video editor"       "$shotcut_state"
        )
    fi
    local ffmpeg_state; ffmpeg_state=$(_state "ffmpeg")
    items+=("ffmpeg" "Multimedia framework (CLI)" "$ffmpeg_state")

    local item_count=${#items[@]}
    local lista_alto=$((item_count > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count))
    local choices
    choices=$(_checklist "Multimedia & Design" "Select multimedia and design tools${SCROLL_HINT}:" \
        $TUI_ALTO $TUI_ANCHO $lista_alto "${items[@]}")
    clear

    [ -z "$choices" ] && return
    local cleaned; cleaned=$(echo "$choices" | tr -d '"')
    for pkg in $cleaned; do
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    echo -e "${GREEN}Multimedia & design tools installed.${NC}"
}
