#!/usr/bin/env bash
# download.sh — Downloaders and Torrent clients (riseup-vpn moved to Internet)

_cat_download() {
    local headless=false
    _is_headless && headless=true
    local -a items1=()
    local -a items2=()
    local aria2_state;       aria2_state=$(_state "aria2")
    local ytdlp_state;       ytdlp_state=$(_state "yt-dlp")
    local deluged_state;     deluged_state=$(_state "deluged")
    local mktorrent_state;   mktorrent_state=$(_state "mktorrent")
    local qbitnox_state;     qbitnox_state=$(_state "qbittorrent-nox")
    local tr_cli_state;      tr_cli_state=$(_state "transmission-cli")
    items1+=(
        "aria2"  "Multiprotocol downloader (CLI)" "$aria2_state"
        "yt-dlp" "Video downloader CLI"         "$ytdlp_state"
    )
    items2+=(
        "deluged"         "BitTorrent daemon/server"           "$deluged_state"
        "mktorrent"       "Torrent metainfo creator (CLI)"   "$mktorrent_state"
        "qbittorrent-nox" "BitTorrent WebUI/CLI"      "$qbitnox_state"
        "transmission-cli" "BitTorrent client (CLI)"  "$tr_cli_state"
    )
    if ! $headless; then
        local filezilla_state;   filezilla_state=$(_state "filezilla")
        local ytdlp_gui_state;   ytdlp_gui_state=$(_state "youtubedl-gui")
        local deluge_state;      deluge_state=$(_state "deluge")
        local qbit_state;        qbit_state=$(_state "qbittorrent")
        local tr_gtk_state;      tr_gtk_state=$(_state "transmission-gtk")
        local tr_qt_state;       tr_qt_state=$(_state "transmission-qt")
        items1+=(
            "filezilla"     "FTP/SFTP client (GUI)"     "$filezilla_state"
            "youtubedl-gui" "GUI for yt-dlp"       "$ytdlp_gui_state"
        )
        items2+=(
            "deluge"          "BitTorrent client (GTK)"           "$deluge_state"
            "qbittorrent"     "BitTorrent client (Qt)"       "$qbit_state"
            "transmission-gtk" "BitTorrent client (GTK)" "$tr_gtk_state"
            "transmission-qt"  "BitTorrent client (Qt)"   "$tr_qt_state"
        )
    fi

    local item_count1=${#items1[@]}
    local lista_alto1=$((item_count1 > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count1))
    local choices1 choices2=""

    choices1=$(_checklist "Downloaders" "Check [*] the packages you want installed/updated on your system.\n" $TUI_ALTO $TUI_ANCHO $lista_alto1 \
        "${items1[@]}" \
        )
    clear

    local item_count2=${#items2[@]}
    local lista_alto2=$((item_count2 > TUI_ALTO_LISTA ? TUI_ALTO_LISTA : item_count2))
    choices2=$(_checklist "Torrent Clients" "Check [*] the packages you want installed/updated on your system.\n" $TUI_ALTO $TUI_ANCHO $lista_alto2 \
        "${items2[@]}" \
        )
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
