#!/bin/bash

# 获取当前脚本所在目录
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 目标路径：让 `panelcnv` 成为全局指令
install_path="/usr/local/bin/panelcnv"

echo "[INFO] Installing panelcnv to $install_path..."

# 赋予 panelcnv 可执行权限
chmod +x "$script_dir/script/panelcnv"

# 软链接到全局路径
if [[ -L "$install_path" || -f "$install_path" ]]; then
    echo "[WARNING] Existing panelcnv found, overwriting..."
    sudo rm -f "$install_path"
fi

sudo ln -s "$script_dir/script/panelcnv" "$install_path"

# 检查是否安装成功
if command -v panelcnv &>/dev/null; then
    echo "[SUCCESS] panelcnv is now installed. You can run:"
    echo "         panelcnv help"
else
    echo "[ERROR] Installation failed. Try running manually:"
    echo "sudo ln -s $script_dir/script/panelcnv /usr/local/bin/panelcnv"
fi
