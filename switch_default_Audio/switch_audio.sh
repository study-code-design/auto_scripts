#!/bin/bash

# ============================================
#   音频设备管理器 - PipeWire (Hyprland)
#   依赖: wpctl, pw-metadata
# ============================================

# ---------- 辅助函数 ----------

# 从 wpctl status 的 Sinks/Sources 节提取设备列表
# 用法: parse_devices "Sinks" 或 parse_devices "Sources"
parse_devices() {
    local section="$1"
    local end_marker
    case "$section" in
        Sinks)   end_marker="Sink endpoints" ;;
        Sources) end_marker="Source endpoints" ;;
        *)       return 1 ;;
    esac

    local raw
    raw=$(wpctl status | sed -n "/$section/,/$end_marker/p" | grep '│')

    echo "$raw" | while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "$line" | grep -q '[0-9]' || continue
        local is_default=0
        echo "$line" | grep -q '\*' && is_default=1

        local clean
        clean=$(echo "$line" | sed 's/^.*│//; s/\[vol:[^]]*\]//g' | xargs)
        clean=$(echo "$clean" | sed 's/\*//' | xargs)

        local id
        id=$(echo "$clean" | cut -d. -f1 | xargs)
        local name
        name=$(echo "$clean" | sed 's/^[0-9]*\. //' | xargs)

        echo "$id|$name|$is_default"
    done
}

# ---------- 菜单 ----------

print_menu() {
    clear 2>/dev/null || true
    echo "=============================="
    echo "   音频设备管理器"
    echo "=============================="
    echo "1. 查询当前默认设备"
    echo "2. 切换扬声器"
    echo "3. 切换麦克风"
    echo "4. 查看所有设备 (含 ALSA 名)"
    echo "5. 退出"
    echo "=============================="
}

# ---------- 功能 1: 查询默认 ----------

query_default() {
    echo ""
    echo "--- 当前默认设备 ---"
    echo ""

    local sink_line source_line
    sink_line=$(wpctl status | sed -n '/Sinks:/,/Sink endpoints/p' | grep '\*' | head -1)
    source_line=$(wpctl status | sed -n '/Sources:/,/Source endpoints/p' | grep '\*' | head -1)

    local sink_info source_info
    if [ -n "$sink_line" ]; then
        sink_info=$(echo "$sink_line" | sed 's/^.*│//; s/\*//; s/\[vol:[^]]*\]//g' | xargs)
    else
        sink_info="(未找到)"
    fi
    if [ -n "$source_line" ]; then
        source_info=$(echo "$source_line" | sed 's/^.*│//; s/\*//; s/\[vol:[^]]*\]//g' | xargs)
    else
        source_info="(未找到)"
    fi

    echo "  扬声器: $sink_info"
    echo "  麦克风: $source_info"
    echo ""

    echo "--- 持久配置 (Settings) ---"
    wpctl status | sed -n '/Settings/,$ p'
    echo ""
}

# ---------- 功能 2/3: 切换 ----------

switch_sink() {
    echo ""
    echo "--- 可用的扬声器 (Sinks) ---"
    echo ""

    local -a ids names
    local i=0
    while IFS='|' read -r id name is_default; do
        [ -z "$id" ] && continue
        ids+=("$id")
        names+=("$name")
        local mark=""
        [ "$is_default" = "1" ] && mark=" ← 当前默认"
        echo "  $((i+1)). [$id] $name$mark"
        ((i++))
    done < <(parse_devices "Sinks")

    [ "$i" -eq 0 ] && { echo "  没有找到扬声器设备。"; return; }

    echo ""
    read -p "输入编号 (1-$i) 选择扬声器, 直接回车取消: " choice

    [ -z "$choice" ] && { echo "已取消。"; return; }

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$i" ]; then
        local idx=$((choice-1))
        local target_id="${ids[$idx]}"
        local target_name="${names[$idx]}"

        echo "切换扬声器到: $target_name (ID: $target_id) ..."
        if wpctl set-default "$target_id" 2>/dev/null; then
            echo "✅ 扬声器已切换。"
        else
            echo "❌ 切换失败。"
        fi
    else
        echo "输入无效。"
    fi
    echo ""
}

switch_source() {
    echo ""
    echo "--- 可用的麦克风 (Sources) ---"
    echo ""

    local -a ids names
    local i=0
    while IFS='|' read -r id name is_default; do
        [ -z "$id" ] && continue
        ids+=("$id")
        names+=("$name")
        local mark=""
        [ "$is_default" = "1" ] && mark=" ← 当前默认"
        echo "  $((i+1)). [$id] $name$mark"
        ((i++))
    done < <(parse_devices "Sources")

    [ "$i" -eq 0 ] && { echo "  没有找到麦克风设备。"; return; }

    echo ""
    read -p "输入编号 (1-$i) 选择麦克风, 直接回车取消: " choice

    [ -z "$choice" ] && { echo "已取消。"; return; }

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "$i" ]; then
        local idx=$((choice-1))
        local target_id="${ids[$idx]}"
        local target_name="${names[$idx]}"

        echo "切换麦克风到: $target_name (ID: $target_id) ..."

        if wpctl set-default "$target_id" 2>/dev/null; then
            echo "✅ 麦克风已切换 (runtime)。"

            local node_name
            node_name=$(wpctl inspect "$target_id" 2>/dev/null | grep -oP 'node.name=\K\S+')
            if [ -n "$node_name" ]; then
                local current
                current=$(pw-metadata -n default 0 default.audio.source 2>/dev/null | grep -oP '"name":"\K[^"]+')
                if [ "$current" != "$node_name" ]; then
                    pw-metadata -n default 0 default.audio.source "{\"name\":\"$node_name\"}" 2>/dev/null
                    echo "  (已同步持久元数据)"
                fi
            fi
        else
            echo "❌ 切换失败。"
        fi
    else
        echo "输入无效。"
    fi
    echo ""
}

# ---------- 功能 4: 查看所有设备 (含 ALSA 名) ----------

list_all_devices() {
    echo ""
    echo "--- 所有音频设备 (含 ALSA node name) ---"
    echo ""

    # 直接从 wpctl status 里提取所有 sink/source 的 ID
    # 只取格式为 " *   XX." 或 "     XX." 的行 (即设备行)
    local all_ids
    all_ids=$(wpctl status | grep -E '│\s+\*?\s+[0-9]+\.' | grep -oP '\d+(?=\.\s)')

    echo "$all_ids" | while IFS= read -r id; do
        [ -z "$id" ] && continue

        local info
        info=$(wpctl inspect "$id" 2>/dev/null)
        local desc name nick
        desc=$(echo "$info" | awk -F'"' '/node.description/{print $2; exit}')
        name=$(echo "$info" | awk -F'"' '/node.name/{print $2; exit}')
        nick=$(echo "$info" | awk -F'"' '/node.nick/{print $2; exit}')

        # 如果 inspect 没取到名字说明不是有效节点，跳过
        [ -z "$name" ] && continue

        local type_label="🔊"
        echo "$info" | grep -q 'capture' && type_label="🎤"

        printf "  %s [%s] %s\n" "$type_label" "$id" "$desc"
        printf "         node.name: %s\n" "$name"
        [ -n "$nick" ] && printf "         node.nick: %s\n" "$nick"
        echo ""
    done
}

# ---------- 主循环 ----------

while true; do
    print_menu
    read -p "请输入选项 [1-5]: " opt

    case "$opt" in
        1) query_default ;;
        2) switch_sink ;;
        3) switch_source ;;
        4) list_all_devices ;;
        5) echo "退出。"; exit 0 ;;
        *) echo "无效选项，请重新输入。" ;;
    esac

    if [ "$opt" != "5" ]; then
        echo ""
        read -p "按回车键返回菜单..."
    fi
done
