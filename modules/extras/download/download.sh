#!/usr/bin/env bash
# download.sh — Downloaders and Torrent clients (riseup-vpn moved to Internet)

_cat_download() {
    local headless=false
    _is_headless && headless=true
    local aria2_state;       aria2_state=$(_state "aria2")
    local filezilla_state;   filezilla_state=$(_state "filezilla")
    local ytdlp_state;       ytdlp_state=$(_state "yt-dlp")
    local ytdlp_gui_state;   ytdlp_gui_state=$(_state "youtubedl-gui")

    local deluge_state;      deluge_state=$(_state "deluge")
    local deluged_state;     deluged_state=$(_state "deluged")
    local mktorrent_state;   mktorrent_state=$(_state "mktorrent")
    local qbit_state;        qbit_state=$(_state "qbittorrent")
    local qbitnox_state;     qbitnox_state=$(_state "qbittorrent-nox")
    local tr_cli_state;      tr_cli_state=$(_state "transmission-cli")
    local tr_gtk_state;      tr_gtk_state=$(_state "transmission-gtk")
    local tr_qt_state;       tr_qt_state=$(_state "transmission-qt")

    local TUI_ANCHO_REFORZADO=$((TUI_ANCHO + 6))
    local choices1 choices2=""

    choices1=$(whiptail --title "Downloaders" --checklist \
        "Select download tools:" $TUI_ALTO $TUI_ANCHO_REFORZADO $TUI_ALTO_LISTA \
        "aria2"            "Multiprotocol downloader (CLI)$(_inst aria2)"     "$aria2_state" \
        "filezilla"        "FTP/SFTP client (GUI)$(_inst filezilla)"          "$filezilla_state" \
        "yt-dlp"           "Video downloader CLI$(_inst yt-dlp)"               "$ytdlp_state" \
        "youtubedl-gui"    "GUI for yt-dlp$(_inst youtubedl-gui)"             "$ytdlp_gui_state" \
        3>&1 1>&2 2>&3)
    clear

    choices2=$(whiptail --title "Torrent Clients" --checklist \
        "Select torrent clients:" $TUI_ALTO $TUI_ANCHO $TUI_ALTO_LISTA \
        "deluge"            "BitTorrent client (GTK)$(_inst deluge)"                      "$deluge_state" \
        "deluged"           "BitTorrent daemon/server$(_inst deluged)"                    "$deluged_state" \
        "mktorrent"         "Torrent metainfo creator (CLI)$(_inst mktorrent)"            "$mktorrent_state" \
        "qbittorrent"       "BitTorrent client (Qt)$(_inst qbittorrent)"                  "$qbit_state" \
        "qbittorrent-nox"   "BitTorrent WebUI/CLI$(_inst qbittorrent-nox)"               "$qbitnox_state" \
        "transmission-cli"  "BitTorrent client (CLI)$(_inst transmission-cli)"            "$tr_cli_state" \
        "transmission-gtk"  "BitTorrent client (GTK)$(_inst transmission-gtk)"            "$tr_gtk_state" \
        "transmission-qt"   "BitTorrent client (Qt)$(_inst transmission-qt)"              "$tr_qt_state" \
        3>&1 1>&2 2>&3)
    clear

    local cleaned
    cleaned=$(echo "$choices1 $choices2" | tr -d '"')

    [ -z "$cleaned" ] && { echo "No download tools selected."; return; }

    for pkg in $cleaned; do
        case $pkg in
            yt-dlp)
                install_backports_or_stable yt-dlp
                ;;
            qbittorrent)
                install_backports_or_stable qbittorrent
                ;;
            qbittorrent-nox)
                install_backports_or_stable qbittorrent-nox
                ;;
            *)
                if $headless; then
                    echo "Skipping $pkg (headless mode)"
                    continue
                fi
                if ! is_installed "$pkg"; then
                    _run_install "$pkg"
                else
                    echo "$pkg already installed."
                fi
                ;;
        esac
    done

    echo -e "${GREEN}Download & network tools installed.${NC}"
}
