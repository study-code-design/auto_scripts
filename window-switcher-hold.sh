#!/usr/bin/env bash

set -euo pipefail

MINHYPR="$HOME/.local/bin/minhypr"
if [ ! -x "$MINHYPR" ]; then
    if command -v minhypr >/dev/null 2>&1; then
        MINHYPR="$(command -v minhypr)"
    else
        notify-send "MinHypr" "Unable to find minhypr executable"
        exit 1
    fi
fi

CACHE_FILE="/tmp/minhypr-state/windows.json"
#THEME="${MINHYPR_WINDOW_THEME:-$HOME/.config/minhypr/minhypr.rasi}"
THEME="/home/tu/Ubuntu-Hyprland-24.04/rofi-1.7.8+wayland1/themes/fancy.rasi"
SCRIPT_NAME="$(basename "$0")"
SKIP_ACCEPT_FILE="/tmp/minhypr-window-switcher-skip-accept"

rofi_running() {
    pgrep -u "$USER" -f "rofi .*${SCRIPT_NAME} --rofi" >/dev/null 2>&1
}

send_rofi_key() {
    local key="$1"
    hyprctl dispatch sendshortcut ", $key, activewindow" >/dev/null 2>&1 || true
}

launch_rofi() {
    local selected_row="${1:-1}"

    rofi \
        -show windows \
        -modi "windows:$0 --rofi" \
        -theme "$THEME" \
        -p "Windows" \
        -i \
        -markup-rows \
        -no-custom \
        -no-fixed-num-lines \
        -show-icons \
        -kb-custom-1 'Delete,Alt+Delete' \
        -kb-remove-char-forward 'Control+d' \
        -selected-row "$selected_row" \
        -theme-str 'window {width: 760px;} element urgent.normal {background-color: #3B4252; text-color: #88C0D0;} element selected.urgent {background-color: #88C0D0; text-color: #2E3440;}'
}

focus_window() {
    local address="$1"
    local hidden="$2"

    if [ "$hidden" = "true" ]; then
        "$MINHYPR" restore "$address" >/dev/null
        hyprctl dispatch focuswindow "address:$address" >/dev/null 2>&1 || true
    else
        hyprctl dispatch focuswindow "address:$address" >/dev/null
    fi

    move_cursor_to_window "$address"
    hyprctl dispatch focuswindow "address:$address" >/dev/null 2>&1 || true
}

close_window() {
    local address="$1"
    local hidden="$2"

    hyprctl dispatch closewindow "address:$address" >/dev/null 2>&1 || true
    date +%s >"$SKIP_ACCEPT_FILE"

    if [ "$hidden" = "true" ] && [ -f "$CACHE_FILE" ]; then
        jq --arg address "$address" 'map(select(.address != $address))' "$CACHE_FILE" >"${CACHE_FILE}.tmp" \
            && mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
        pkill -RTMIN+8 waybar >/dev/null 2>&1 || true
    fi
}

move_cursor_to_window() {
    local address="$1"
    local geometry
    local x
    local y

    geometry="$(
        hyprctl clients -j | jq -r --arg address "$address" '
            .[]
            | select(.address == $address)
            | "\((.at[0] + (.size[0] / 2)) | floor) \((.at[1] + (.size[1] / 2)) | floor)"
        ' | head -n 1
    )"

    if [ -z "$geometry" ]; then
        return 0
    fi

    read -r x y <<<"$geometry"
    if [ -n "$x" ] && [ -n "$y" ]; then
        hyprctl dispatch movecursor "$x" "$y" >/dev/null 2>&1 || true
        hyprctl dispatch movecursor "$((x + 1))" "$y" >/dev/null 2>&1 || true
        hyprctl dispatch movecursor "$x" "$y" >/dev/null 2>&1 || true
    fi
}

if [ -n "${ROFI_INFO:-}" ]; then
    IFS='|' read -r address hidden _ <<<"$ROFI_INFO"
    if [ -n "$address" ]; then
        if [ "${ROFI_RETV:-0}" = "10" ]; then
            close_window "$address" "${hidden:-false}"
        else
            (
                sleep 0.08
                focus_window "$address" "${hidden:-false}"
                sleep 0.05
                focus_window "$address" "${hidden:-false}"
            ) >/tmp/minhypr-window-switcher.log 2>&1 &
            exit 0
        fi
    fi
fi

case "${1:-}" in
    --accept)
        if [ -f "$SKIP_ACCEPT_FILE" ]; then
            now="$(date +%s)"
            then="$(cat "$SKIP_ACCEPT_FILE" 2>/dev/null || printf 0)"
            rm -f "$SKIP_ACCEPT_FILE"

            if [ "$((now - then))" -le 2 ]; then
                exit 0
            fi
        fi

        if rofi_running; then
            send_rofi_key "Return"
        fi
        exit 0
        ;;
    --next|"")
        if rofi_running; then
            send_rofi_key "Down"
        else
            launch_rofi 1
        fi
        exit 0
        ;;
    --prev)
        if rofi_running; then
            send_rofi_key "Up"
        else
            launch_rofi 1
        fi
        exit 0
        ;;
esac

if [ "${1:-}" = "--rofi" ]; then
    clients_json="$(hyprctl clients -j)"
    minimized_json="[]"
    if [ -f "$CACHE_FILE" ]; then
        minimized_json="$(jq -c . "$CACHE_FILE" 2>/dev/null || printf '[]')"
    fi

    printf '\0use-hot-keys\x1ftrue\n'
    if [ "${ROFI_RETV:-0}" = "10" ]; then
        printf '\0keep-selection\x1ftrue\n'
        printf '\0keep-filter\x1ftrue\n'
    fi

    jq -r --argjson minimized "$minimized_json" '
        def app_name:
            (. // "unknown")
            | ascii_downcase
            | if test("google-chrome|chrome") then "chrome"
              elif test("code|vscode|visual-studio-code") then "code"
              else .
              end;

        def short_title:
            (.title // "")
            | gsub("[\n\r\t]+"; " ")
            | gsub(" +"; " ")
            | if length > 120 then .[0:117] + "..." else . end;

        def row_label($app; $title):
            "\($app) - \($title)";

        ($minimized | map(.address)) as $hidden_addresses
        | sort_by(.focusHistoryID // 999999)
        | .[]
        | .address as $address
        | (.class | app_name) as $app
        | (short_title) as $title
        | (($hidden_addresses | index($address)) != null or .workspace.name == "special:minimized") as $hidden
        | if $hidden then
            "<span foreground=\"#88C0D0\" weight=\"bold\">\(row_label($app; $title) | @html)</span>"
            + "\u0000icon\u001f\($app)\u001finfo\u001f\($address)|true\u001furgent\u001ftrue"
          else
            "\(row_label($app; $title) | @html)"
            + "\u0000icon\u001f\($app)\u001finfo\u001f\($address)|false"
          end
    ' <<<"$clients_json"
    exit 0
fi
