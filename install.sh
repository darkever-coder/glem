#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

#######################################################
# Termux Desktop / Dev One-Go Installer
#
# Installs:
# - XFCE desktop + Termux-X11
# - GPU acceleration (Turnip/Zink when possible)
# - Firefox, Code-OSS, Python, Git, Node.js
# - proot + proot-distro
# - fake sudo wrapper
# - .NET 8 native Termux package
#
# Start desktop with:
#   ./start.sh
# Stop desktop with:
#   ./stop.sh
#######################################################

TOTAL_STEPS=15
CURRENT_STEP=0
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
HOME_DIR="${HOME:-/data/data/com.termux/files/home}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    FILLED=$((PERCENT / 5))
    EMPTY=$((20 - FILLED))

    BAR="${GREEN}"
    for ((i=0; i<FILLED; i++)); do BAR+="█"; done
    BAR+="${GRAY}"
    for ((i=0; i<EMPTY; i++)); do BAR+="░"; done
    BAR+="${NC}"

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r  ${YELLOW}⏳${NC} %s ${CYAN}%s${NC}  " "$message" "${spin:$i:1}"
        sleep 0.1
    done

    wait "$pid"
    local exit_code=$?

    if [ "$exit_code" -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC} %s                                      \n" "$message"
    else
        printf "\r  ${RED}✗${NC} %s ${RED}(failed)${NC}                        \n" "$message"
    fi

    return "$exit_code"
}

run_bg() {
    local msg="$1"
    shift
    ("$@" > /dev/null 2>&1) &
    spinner $! "$msg"
}

install_pkg() {
    local pkg="$1"
    local name="${2:-$pkg}"
    run_bg "Installing ${name}..." pkg install -y "$pkg"
}

pkg_exists() {
    pkg show "$1" > /dev/null 2>&1
}

install_if_available() {
    local pkg="$1"
    local name="${2:-$pkg}"
    if pkg_exists "$pkg"; then
        install_pkg "$pkg" "$name"
    else
        echo -e "  ${YELLOW}•${NC} ${name} not available, skipping."
    fi
}

append_once() {
    local line="$1"
    local file="$2"
    touch "$file"
    grep -Fqx "$line" "$file" 2>/dev/null || echo "$line" >> "$file"
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════╗
║        TERMUX DESKTOP / DEV INSTALLER        ║
║              One-Go Setup Script             ║
╚══════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo ""
}

detect_device() {
    echo -e "${PURPLE}[*] Detecting device...${NC}"
    echo ""

    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    CPU_ABI=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64-v8a")
    GPU_VENDOR=$(getprop ro.hardware.egl 2>/dev/null || echo "")

    echo -e "  ${GREEN}Device:${NC} ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  ${GREEN}Android:${NC} ${WHITE}${ANDROID_VERSION}${NC}"
    echo -e "  ${GREEN}CPU:${NC} ${WHITE}${CPU_ABI}${NC}"

    if [[ "$GPU_VENDOR" == *"adreno"* ]] || [[ "$DEVICE_BRAND" =~ ^(samsung|Samsung|oneplus|OnePlus|xiaomi|Xiaomi)$ ]]; then
        GPU_DRIVER="freedreno"
        echo -e "  ${GREEN}GPU:${NC} ${WHITE}Turnip/Freedreno path${NC}"
    else
        GPU_DRIVER="swrast"
        echo -e "  ${GREEN}GPU:${NC} ${WHITE}Software fallback path${NC}"
    fi
    echo ""
}

step_update() {
    update_progress
    echo -e "${PURPLE}Updating packages...${NC}"
    run_bg "Updating package index..." pkg update -y
    run_bg "Upgrading installed packages..." pkg upgrade -y
}

step_repos() {
    update_progress
    echo -e "${PURPLE}Enabling repositories...${NC}"
    install_if_available "x11-repo" "X11 repo"
    install_if_available "tur-repo" "TUR repo"
    install_if_available "root-repo" "Root repo"
}

step_base() {
    update_progress
    echo -e "${PURPLE}Installing base tools...${NC}"
    install_pkg "wget" "Wget"
    install_pkg "curl" "cURL"
    install_pkg "git" "Git"
    install_pkg "python" "Python"
    install_pkg "pip" "Pip"
    install_pkg "clang" "Clang"
    install_pkg "make" "Make"
    install_pkg "pkg-config" "pkg-config"
    install_pkg "tar" "tar"
    install_pkg "zip" "zip"
    install_pkg "unzip" "unzip"
    install_pkg "nano" "Nano"
    install_pkg "vim" "Vim"
    install_pkg "openssh" "OpenSSH"
}

step_proot() {
    update_progress
    echo -e "${PURPLE}Installing proot environment...${NC}"
    install_pkg "proot" "proot"
    install_pkg "proot-distro" "proot-distro"
    install_if_available "tsu" "tsu"
}

step_node_git_dotnet() {
    update_progress
    echo -e "${PURPLE}Installing Node.js / Git / .NET 8...${NC}"

    if pkg_exists "nodejs-lts"; then
        install_pkg "nodejs-lts" "Node.js LTS"
    else
        install_pkg "nodejs" "Node.js"
    fi

    install_pkg "git" "Git"

    # Current native Termux .NET 8 package
    if pkg_exists "dotnet-sdk-8.0"; then
        install_pkg "dotnet-sdk-8.0" ".NET SDK 8"
    else
        echo -e "  ${YELLOW}•${NC} dotnet-sdk-8.0 not found in this repo/device. Skipping."
    fi
}

step_x11() {
    update_progress
    echo -e "${PURPLE}Installing X11 stack...${NC}"
    install_if_available "termux-x11-nightly" "Termux-X11 nightly"
    install_if_available "xorg-xrandr" "XRandR"
    install_if_available "dbus" "DBus"
}

step_desktop() {
    update_progress
    echo -e "${PURPLE}Installing XFCE desktop...${NC}"
    install_pkg "xfce4" "XFCE4"
    install_pkg "xfce4-terminal" "XFCE terminal"
    install_pkg "thunar" "Thunar"
    install_pkg "mousepad" "Mousepad"
}

step_gpu() {
    update_progress
    echo -e "${PURPLE}Installing GPU acceleration packages...${NC}"
    install_if_available "mesa-zink" "Mesa Zink"

    if [ "${GPU_DRIVER}" = "freedreno" ]; then
        install_if_available "mesa-vulkan-icd-freedreno" "Freedreno Vulkan"
    else
        install_if_available "mesa-vulkan-icd-swrast" "Software Vulkan"
    fi

    install_if_available "vulkan-loader-android" "Vulkan loader"
    install_if_available "mesa-utils" "Mesa utilities"
}

step_audio() {
    update_progress
    echo -e "${PURPLE}Installing audio...${NC}"
    install_pkg "pulseaudio" "PulseAudio"
}

step_apps() {
    update_progress
    echo -e "${PURPLE}Installing desktop apps...${NC}"
    install_if_available "firefox" "Firefox"
    install_if_available "code-oss" "Code-OSS"
}

step_python_libs() {
    update_progress
    echo -e "${PURPLE}Installing Python libraries...${NC}"
    run_bg "Installing Python libraries..." pip install --upgrade pip requests beautifulsoup4 ipython
}

step_fake_sudo() {
    update_progress
    echo -e "${PURPLE}Creating fake sudo...${NC}"

    cat > "${PREFIX}/bin/sudo" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
if [ $# -eq 0 ]; then
    echo "Usage: sudo <command>"
    exit 1
fi
echo "[fake sudo] Running as Termux user: $*"
exec "$@"
EOF
    chmod +x "${PREFIX}/bin/sudo"
    echo -e "  ${GREEN}✓${NC} fake sudo installed"
}

step_shell_setup() {
    update_progress
    echo -e "${PURPLE}Configuring shell...${NC}"

    mkdir -p "${HOME_DIR}/.config"

    cat > "${HOME_DIR}/.config/hacklab-gpu.sh" << 'EOF'
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=immediate
export ZINK_DESCRIPTORS=lazy
EOF

    append_once 'source ~/.config/hacklab-gpu.sh 2>/dev/null' "${HOME_DIR}/.bashrc"
    append_once 'export PATH=$PREFIX/bin:$PATH' "${HOME_DIR}/.bashrc"
    append_once 'alias ll="ls -lah"' "${HOME_DIR}/.bashrc"
    append_once 'alias py="python"' "${HOME_DIR}/.bashrc"
}

step_launchers() {
    update_progress
    echo -e "${PURPLE}Creating start/stop scripts...${NC}"

    cat > "${HOME_DIR}/start.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

echo ""
echo "Starting desktop..."
echo ""

source ~/.config/hacklab-gpu.sh 2>/dev/null

pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "xfce" 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null
pkill -9 -f "pulseaudio" 2>/dev/null

unset PULSE_SERVER
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null || true
export PULSE_SERVER=127.0.0.1

termux-x11 :0 -ac &
sleep 3

export DISPLAY=:0
export XDG_RUNTIME_DIR="${TMPDIR}"

if command -v dbus-launch >/dev/null 2>&1; then
    exec dbus-launch --exit-with-session startxfce4
else
    exec startxfce4
fi
EOF
    chmod +x "${HOME_DIR}/start.sh"

    cat > "${HOME_DIR}/stop.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "xfce" 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null
pkill -9 -f "pulseaudio" 2>/dev/null
echo "Desktop stopped."
EOF
    chmod +x "${HOME_DIR}/stop.sh"

    cat > "${HOME_DIR}/devcheck.sh" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "=== Tool check ==="
command -v git >/dev/null 2>&1 && git --version
command -v node >/dev/null 2>&1 && node --version
command -v npm >/dev/null 2>&1 && npm --version
command -v python >/dev/null 2>&1 && python --version
command -v dotnet >/dev/null 2>&1 && dotnet --info | head -n 20
command -v proot >/dev/null 2>&1 && echo "proot: OK"
command -v proot-distro >/dev/null 2>&1 && echo "proot-distro: OK"
command -v sudo >/dev/null 2>&1 && echo "sudo: fake wrapper installed"
EOF
    chmod +x "${HOME_DIR}/devcheck.sh"

    echo -e "  ${GREEN}✓${NC} Created ~/start.sh"
    echo -e "  ${GREEN}✓${NC} Created ~/stop.sh"
    echo -e "  ${GREEN}✓${NC} Created ~/devcheck.sh"
}

step_shortcuts() {
    update_progress
    echo -e "${PURPLE}Creating desktop shortcuts...${NC}"

    mkdir -p "${HOME_DIR}/Desktop"

    cat > "${HOME_DIR}/Desktop/Firefox.desktop" << 'EOF'
[Desktop Entry]
Name=Firefox
Exec=firefox
Icon=firefox
Type=Application
Categories=Network;WebBrowser;
EOF

    cat > "${HOME_DIR}/Desktop/CodeOSS.desktop" << 'EOF'
[Desktop Entry]
Name=Code-OSS
Exec=code-oss --no-sandbox
Icon=code-oss
Type=Application
Categories=Development;
EOF

    cat > "${HOME_DIR}/Desktop/Terminal.desktop" << 'EOF'
[Desktop Entry]
Name=Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Type=Application
Categories=System;TerminalEmulator;
EOF

    chmod +x "${HOME_DIR}"/Desktop/*.desktop 2>/dev/null || true
}

step_finish() {
    update_progress
    echo -e "${PURPLE}Finalizing...${NC}"
    echo ""
    echo -e "${GREEN}Installation complete.${NC}"
    echo ""
    echo -e "${WHITE}Start desktop:${NC} ${GREEN}cd ~ && ./start.sh${NC}"
    echo -e "${WHITE}Stop desktop:${NC}  ${GREEN}cd ~ && ./stop.sh${NC}"
    echo -e "${WHITE}Check tools:${NC}   ${GREEN}cd ~ && ./devcheck.sh${NC}"
    echo ""
    echo -e "${WHITE}For native Termux packages later:${NC}"
    echo -e "  ${GREEN}pkg install <package>${NC}"
    echo -e "  ${GREEN}sudo pkg install <package>${NC} ${GRAY}(fake sudo only)${NC}"
    echo ""
    echo -e "${WHITE}For proot Linux later:${NC}"
    echo -e "  ${GREEN}proot-distro install ubuntu${NC}"
    echo -e "  ${GREEN}proot-distro login ubuntu${NC}"
    echo ""
    echo -e "${YELLOW}Open the Termux-X11 app, then run ./start.sh${NC}"
}

main() {
    show_banner
    echo -e "${WHITE}This installs a one-go Termux desktop/dev setup.${NC}"
    echo -e "${WHITE}Press Enter to continue, or Ctrl+C to cancel.${NC}"
    read -r

    detect_device
    step_update
    step_repos
    step_base
    step_proot
    step_node_git_dotnet
    step_x11
    step_desktop
    step_gpu
    step_audio
    step_apps
    step_python_libs
    step_fake_sudo
    step_shell_setup
    step_launchers
    step_shortcuts
    step_finish
}

main "$@"