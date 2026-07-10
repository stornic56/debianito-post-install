#!/usr/bin/env bash
# design.sh — Multimedia & Design (handbrake moved here from Media Players)

_cat_design() {
    local headless=false
    _is_headless && headless=true
    local audacity_state;  audacity_state=$(_state "audacity")
    local ardour_state;    ardour_state=$(_state "ardour")
    local blender_state;   blender_state=$(_state "blender")
    local ffmpeg_state;    ffmpeg_state=$(_state "ffmpeg")
    local gimp_state;      gimp_state=$(_state "gimp")
    local handbrake_state; handbrake_state=$(_state "handbrake")
    local inkscape_state;  inkscape_state=$(_state "inkscape")
    local kdenlive_state;  kdenlive_state=$(_state "kdenlive")
    local krita_state;     krita_state=$(_state "krita")
    local obs_state;       obs_state=$(_state "obs-studio")
    local openshot_state;  openshot_state=$(_state "openshot-qt")
    local scribus_state;   scribus_state=$(_state "scribus")
    local shotcut_state;   shotcut_state=$(_state "shotcut")

    local choices
    choices=$(_checklist "Multimedia & Design" "Select multimedia and design tools${SCROLL_HINT}:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "audacity"   "Audio editor/recorder$(_inst audacity)"                  "$audacity_state" \
        "ardour"     "Digital audio workstation$(_inst ardour)"                "$ardour_state" \
        "blender"    "3D modeling/animation suite$(_inst blender)"             "$blender_state" \
        "ffmpeg"     "Multimedia framework (CLI)$(_inst ffmpeg)"               "$ffmpeg_state" \
        "gimp"       "Image editor (Photoshop alternative)$(_inst gimp)"       "$gimp_state" \
        "handbrake"  "Video transcoder (DVD ripper)$(_inst handbrake)"         "$handbrake_state" \
        "inkscape"   "Vector graphics editor$(_inst inkscape)"                 "$inkscape_state" \
        "kdenlive"   "Video editor (KDE)$(_inst kdenlive)"                     "$kdenlive_state" \
        "krita"      "Digital painting/illustration$(_inst krita)"             "$krita_state" \
        "obs-studio" "Screen recording/streaming$(_inst obs-studio)"           "$obs_state" \
        "openshot-qt" "Video editor (simple)$(_inst openshot-qt)"              "$openshot_state" \
        "scribus"    "Desktop publishing (DTP)$(_inst scribus)"                "$scribus_state" \
        "shotcut"    "Video editor (cross-platform)$(_inst shotcut)"           "$shotcut_state" \
        )
    clear

    [ -z "$choices" ] && return

    local cleaned; cleaned=$(echo "$choices" | tr -d '"')

    for pkg in $cleaned; do
        if $headless; then
            echo "Skipping $pkg (headless mode)"
            continue
        fi
        if ! is_installed "$pkg"; then
            _run_install "$pkg"
        else
            echo "$pkg already installed."
        fi
    done

    echo -e "${GREEN}Multimedia & design tools installed.${NC}"
}
