# this blog aim to solve that bluetooth headsset problem

## problem:the built-in audio apparatus can work,but can't work when I connect the PC with bluetooth 

1. `sudo pacman -S --needed bluez-utils` install bluetoothctl
2. `sudo vim /etc/bluetooth/main.conf` add  
```bash
[General]
# 禁用 HFP/HSP 协议，强制只使用 A2DP 音乐模式
Disable=Headset
# 确保启用媒体传输
Enable=Source,Sink,Media
```
3. 
```# 重启蓝牙服务
sudo systemctl restart bluetooth
sleep 3

# 安装 bluetoothctl（如未安装）
sudo pacman -S --needed bluez-utils

# 断开重连 + 切换到最稳定的 SBC codec
bluetoothctl disconnect A4:90:CE:17:8F:58 2>/dev/null || true
sleep 2
bluetoothctl connect A4:90:CE:17:8F:58
sleep 5
pactl set-card-profile bluez_card.A4_90_CE_17_8F_58 a2dp-sink-sbc

# 重启音频栈重建通道
systemctl --user restart wireplumber pipewire
sleep 5
```


4.verification scripts
```bash
# 获取 sink ID（绕过冒号问题）
SINK_ID=$(pactl list short sinks | grep -i "bluez_output" | awk '{print $1}' | head -1)

if [ -n "$SINK_ID" ]; then
    # 设置默认输出（必须用 ID）
    pactl set-default-sink $SINK_ID
    
    # 测试播放（多方案备用）
    sudo pacman -S --needed sound-theme-freedesktop
    paplay /usr/share/sounds/freedesktop/stereo/audio-volume-high.oga || \
    pw-play /usr/share/sounds/freedesktop/stereo/audio-volume-high.oga
    
    # 验证状态
    echo "✅ 当前状态："
    pactl list sinks | grep -A 2 "Sink #$SINK_ID" | grep "State:"
else
    echo "❌ 未检测到蓝牙 sink，请检查："
    pactl list short sinks
fi
```