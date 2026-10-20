确保安装了这个

```bash
sudo pacman -S fcitx5-gtk fcitx5-qt

```

安装好微信之后，在`/usr/share/applications/`或者`~/.local/share/applications/`下
找到微信

```desktop
Exec=env GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx /usr/bin/wechat --ozone-platform-hint=auto --enable-wayland-ime %U
```

