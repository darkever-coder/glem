#!/data/data/com.termux/files/usr/bin/bash

# Force bash (fix pipe issues)
if [ -z "${BASH_VERSION:-}" ]; then
    exec bash "$0" "$@"
fi

set -euo pipefail

PREFIX=/data/data/com.termux/files/usr
HOME_DIR=$HOME

echo "=== TERMUX FULL DEV SETUP ==="
echo ""

# =============================
# BASIC SETUP
# =============================
pkg update -y
pkg upgrade -y

pkg install -y \
  x11-repo tur-repo root-repo \
  wget curl git python pip \
  nodejs-lts clang make pkg-config \
  zip unzip tar nano vim \
  openssh which

# =============================
# PROOT
# =============================
pkg install -y proot proot-distro

# =============================
# .NET 8 (TERMUX)
# =============================
if pkg show dotnet-sdk-8.0 > /dev/null 2>&1; then
    pkg install -y dotnet-sdk-8.0
else
    echo "dotnet-sdk-8.0 not available, skipping native .NET"
fi

# =============================
# X11 + DESKTOP
# =============================
pkg install -y termux-x11-nightly xfce4 xfce4-terminal thunar mousepad dbus

# =============================
# GPU (BEST EFFORT)
# =============================
pkg install -y mesa-zink mesa-utils vulkan-loader-android || true
pkg install -y mesa-vulkan-icd-freedreno || true

# =============================
# AUDIO
# =============================
pkg install -y pulseaudio

# =============================
# APPS
# =============================
pkg install -y firefox code-oss || true

# =============================
# PYTHON LIBS
# =============================
pip install --upgrade pip
pip install requests beautifulsoup4 ipython

# =============================
# FAKE SUDO
# =============================
cat > $PREFIX/bin/sudo << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "[fake sudo] $@"
exec "$@"
EOF
chmod +x $PREFIX/bin/sudo

# =============================
# GPU CONFIG
# =============================
mkdir -p ~/.config
cat > ~/.config/gpu.sh << 'EOF'
export MESA_NO_ERROR=1
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
EOF

grep -q gpu.sh ~/.bashrc || echo "source ~/.config/gpu.sh" >> ~/.bashrc

# =============================
# START SCRIPT
# =============================
cat > ~/start.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

source ~/.config/gpu.sh 2>/dev/null

pkill -9 termux.x11 2>/dev/null
pkill -9 xfce 2>/dev/null
pkill -9 pulseaudio 2>/dev/null

pulseaudio --start
sleep 1

termux-x11 :0 -ac &
sleep 3

export DISPLAY=:0
exec dbus-launch --exit-with-session startxfce4
EOF

chmod +x ~/start.sh

# =============================
# STOP SCRIPT
# =============================
cat > ~/stop.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill -9 termux.x11
pkill -9 xfce
pkill -9 pulseaudio
echo "Stopped"
EOF

chmod +x ~/stop.sh

# =============================
# UBUNTU PROOT INSTALL
# =============================
if [ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu" ]; then
    proot-distro install ubuntu
fi

# =============================
# UBUNTU SETUP
# =============================
cat > ~/.ubuntu-setup.sh << 'EOF'
#!/bin/bash
set -e

apt update
apt install -y curl wget git python3 python3-pip nodejs npm

# .NET 8 install
curl -sSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel 8.0

echo 'export DOTNET_ROOT=$HOME/.dotnet' >> ~/.bashrc
echo 'export PATH=$HOME/.dotnet:$PATH' >> ~/.bashrc
EOF

chmod +x ~/.ubuntu-setup.sh

proot-distro login ubuntu -- /bin/bash /data/data/com.termux/files/home/.ubuntu-setup.sh

# =============================
# UBUNTU LAUNCHER
# =============================
cat > ~/ubuntu.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login ubuntu
EOF

chmod +x ~/ubuntu.sh

# =============================
# DONE
# =============================
echo ""
echo "=== DONE ==="
echo ""
echo "Start desktop:"
echo "  ./start.sh"
echo ""
echo "Stop desktop:"
echo "  ./stop.sh"
echo ""
echo "Ubuntu:"
echo "  ./ubuntu.sh"
echo ""
