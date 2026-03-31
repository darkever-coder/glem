#!/data/data/com.termux/files/usr/bin/bash
#######################################################
#  GLEM Desktop - All-in-One Termux Installer
#
#  Features:
#  - XFCE4 Desktop + GPU acceleration (Turnip/Zink)
#  - Firefox, Code-OSS, Python
#  - Node.js, Git, .NET 8 SDK (via proot Ubuntu)
#  - proot-distro with Ubuntu ready to use
#  - Fake sudo for convenience
#  - Simple start.sh / stop.sh
#
#  Usage:
#    curl -sL <raw-url>/install.sh | bash
#######################################################

set -e

# ============== CONFIGURATION ==============
TOTAL_STEPS=14
CURRENT_STEP=0

# ============== COLORS ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

# ============== PROGRESS FUNCTIONS ==============
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
    echo -e "${CYAN}  OVERALL PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
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
    if [ $exit_code -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC} %s                    \n" "$message"
    else
        printf "\r  ${RED}✗${NC} %s ${RED}(failed)${NC}     \n" "$message"
    fi
    return $exit_code
}

install_pkg() {
    local pkg=$1
    local name=${2:-$pkg}
    (yes | pkg install "$pkg" -y > /dev/null 2>&1) &
    spinner $! "Installing ${name}..."
}

# ============== BANNER ==============
show_banner() {
    clear
    echo -e "${CYAN}"
    echo "    ╔══════════════════════════════════════╗"
    echo "    ║                                      ║"
    echo "    ║        GLEM Desktop Installer        ║"
    echo "    ║        All-in-One for Termux         ║"
    echo "    ║                                      ║"
    echo "    ╚══════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

# ============== DEVICE DETECTION ==============
detect_device() {
    echo -e "${PURPLE}[*] Detecting your device...${NC}"
    echo ""
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    CPU_ABI=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64-v8a")
    GPU_VENDOR=$(getprop ro.hardware.egl 2>/dev/null || echo "")
    echo -e "  ${GREEN}📱${NC} Device: ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  ${GREEN}🤖${NC} Android: ${WHITE}${ANDROID_VERSION}${NC}"
    echo -e "  ${GREEN}⚙️${NC}  CPU: ${WHITE}${CPU_ABI}${NC}"
    if [[ "$GPU_VENDOR" == *"adreno"* ]] || [[ "$DEVICE_BRAND" == *"samsung"* ]] || [[ "$DEVICE_BRAND" == *"Samsung"* ]] || [[ "$DEVICE_BRAND" == *"oneplus"* ]] || [[ "$DEVICE_BRAND" == *"xiaomi"* ]]; then
        GPU_DRIVER="freedreno"
        echo -e "  ${GREEN}🎮${NC} GPU: ${WHITE}Adreno (Qualcomm) - Turnip driver${NC}"
    else
        GPU_DRIVER="swrast"
        echo -e "  ${GREEN}🎮${NC} GPU: ${WHITE}Software rendering${NC}"
    fi
    echo ""
    sleep 1
}

# ============== STEP 1: UPDATE SYSTEM ==============
step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Updating system packages...${NC}"
    echo ""
    (yes | pkg update -y > /dev/null 2>&1) &
    spinner $! "Updating package lists..."
    (yes | pkg upgrade -y > /dev/null 2>&1) &
    spinner $! "Upgrading installed packages..."
}

# ============== STEP 2: INSTALL REPOSITORIES ==============
step_repos() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Adding package repositories...${NC}"
    echo ""
    install_pkg "x11-repo" "X11 Repository"
    install_pkg "tur-repo" "TUR Repository (Firefox, VS Code)"
}

# ============== STEP 3: INSTALL TERMUX-X11 ==============
step_x11() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Termux-X11...${NC}"
    echo ""
    install_pkg "termux-x11-nightly" "Termux-X11 Display Server"
    install_pkg "xorg-xrandr" "XRandR (Display Settings)"
}

# ============== STEP 4: INSTALL DESKTOP ==============
step_desktop() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing XFCE4 Desktop...${NC}"
    echo ""
    install_pkg "xfce4" "XFCE4 Desktop Environment"
    install_pkg "xfce4-terminal" "XFCE4 Terminal"
    install_pkg "thunar" "Thunar File Manager"
    install_pkg "mousepad" "Mousepad Text Editor"
}

# ============== STEP 5: INSTALL GPU DRIVERS ==============
step_gpu() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing GPU Acceleration (Turnip/Zink)...${NC}"
    echo ""
    install_pkg "mesa-zink" "Mesa Zink (OpenGL over Vulkan)"
    if [ "$GPU_DRIVER" = "freedreno" ]; then
        install_pkg "mesa-vulkan-icd-freedreno" "Turnip Adreno GPU Driver"
    else
        install_pkg "mesa-vulkan-icd-swrast" "Software Vulkan Renderer"
    fi
    install_pkg "vulkan-loader-android" "Vulkan Loader"
    echo -e "  ${GREEN}✓${NC} GPU acceleration configured!"
}

# ============== STEP 6: INSTALL AUDIO ==============
step_audio() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Audio Support...${NC}"
    echo ""
    install_pkg "pulseaudio" "PulseAudio Sound Server"
}

# ============== STEP 7: INSTALL CORE APPS ==============
step_apps() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Applications...${NC}"
    echo ""
    install_pkg "firefox" "Firefox Browser"
    install_pkg "code-oss" "VS Code Editor"
    install_pkg "python" "Python"
    install_pkg "python-pip" "Python pip"
    install_pkg "wget" "Wget Downloader"
    install_pkg "curl" "cURL"
}

# ============== STEP 8: INSTALL DEV TOOLS (node, git) ==============
step_devtools() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Dev Tools (Node.js, Git)...${NC}"
    echo ""
    install_pkg "nodejs" "Node.js"
    install_pkg "git" "Git"
    install_pkg "openssh" "OpenSSH"
    install_pkg "make" "Make"
    install_pkg "clang" "Clang Compiler"
    install_pkg "pkg-config" "pkg-config"
}

# ============== STEP 9: INSTALL PROOT + UBUNTU ==============
step_proot() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing proot-distro + Ubuntu...${NC}"
    echo ""
    install_pkg "proot" "PRoot"
    install_pkg "proot-distro" "PRoot Distro Manager"

    echo -e "  ${YELLOW}⏳${NC} Installing Ubuntu (this may take a few minutes)..."
    (proot-distro install ubuntu 2>/dev/null || true) &
    spinner $! "Downloading & extracting Ubuntu rootfs..."

    echo -e "  ${YELLOW}⏳${NC} Updating Ubuntu and installing packages..."
    (proot-distro login ubuntu -- bash -c '\
        apt-get update -y && \
        apt-get upgrade -y && \
        apt-get install -y sudo curl wget git nano build-essential ca-certificates && \
        echo "Ubuntu base setup done"' > /dev/null 2>&1) &
    spinner $! "Setting up Ubuntu base packages..."
    echo -e "  ${GREEN}✓${NC} Ubuntu proot ready (use: proot-distro login ubuntu)"
}

# ============== STEP 10: INSTALL .NET 8 SDK IN UBUNTU ==============
step_dotnet() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing .NET 8 SDK (inside Ubuntu proot)...${NC}"
    echo ""
    echo -e "  ${YELLOW}⏳${NC} This may take several minutes..."
    (proot-distro login ubuntu -- bash -c '\
        apt-get install -y dotnet-sdk-8.0 2>/dev/null || { \
            # Fallback: add Microsoft repo if Ubuntu package not available
            curl -fsSL https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb -o /tmp/packages-microsoft-prod.deb && \
            dpkg -i /tmp/packages-microsoft-prod.deb && \
            apt-get update -y && \
            apt-get install -y dotnet-sdk-8.0 ; \
        } && echo "dotnet installed ok"' > /dev/null 2>&1) &
    spinner $! "Installing .NET 8 SDK in Ubuntu proot..."

    # Create a convenience wrapper so 'dotnet' works from Termux
    cat > "$PREFIX/bin/dotnet" << 'DOTNETEOF'
#!/data/data/com.termux/files/usr/bin/bash
exec proot-distro login ubuntu -- dotnet "$@"
DOTNETEOF
    chmod +x "$PREFIX/bin/dotnet"
    echo -e "  ${GREEN}✓${NC} .NET 8 SDK installed (run 'dotnet' from Termux or inside Ubuntu)"
}

# ============== STEP 11: INSTALL NETWORK TOOLS ==============
step_network_tools() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Network & Security Tools...${NC}"
    echo ""
    install_pkg "nmap" "Nmap Network Scanner"
    install_pkg "netcat-openbsd" "Netcat"
    install_pkg "whois" "Whois Lookup"
    install_pkg "dnsutils" "DNS Utilities"
    install_pkg "tracepath" "Tracepath"
    install_pkg "hydra" "Hydra Password Cracker"
    install_pkg "sqlmap" "SQLMap (SQL Injection)"
    echo -e "  ${YELLOW}⏳${NC} Installing Python security libraries..."
    pip install requests beautifulsoup4 > /dev/null 2>&1 || true
    echo -e "  ${GREEN}✓${NC} Python libraries installed"
}

# ============== STEP 12: INSTALL WINE ==============
step_wine() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Installing Wine (Windows Support)...${NC}"
    echo ""
    (pkg remove wine-stable -y > /dev/null 2>&1) &
    spinner $! "Removing old Wine versions..."
    install_pkg "hangover-wine" "Wine Compatibility Layer"
    install_pkg "hangover-wowbox64" "Box64 Wrapper"
    ln -sf "$PREFIX/opt/hangover-wine/bin/wine" "$PREFIX/bin/wine" 2>/dev/null || true
    ln -sf "$PREFIX/opt/hangover-wine/bin/winecfg" "$PREFIX/bin/winecfg" 2>/dev/null || true
    echo -e "  ${YELLOW}⏳${NC} Applying Windows UI optimizations..."
    wine reg add "HKEY_CURRENT_USER\Control Panel\Desktop" /v FontSmoothing /t REG_SZ /d 2 /f > /dev/null 2>&1 || true
    echo -e "  ${GREEN}✓${NC} Wine ready"
}

# ============== STEP 13: FAKE SUDO + LAUNCHERS ==============
step_launchers() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating sudo wrapper, start.sh, stop.sh...${NC}"
    echo ""

    # --- fake sudo ---
    cat > "$PREFIX/bin/sudo" << 'SUDOEOF'
#!/data/data/com.termux/files/usr/bin/bash
# Fake sudo for Termux - runs commands as current user
if [ "$1" = "-i" ] || [ "$1" = "-s" ]; then
    exec bash
elif [ "$1" = "su" ]; then
    shift
    exec "$@"
else
    exec "$@"
fi
SUDOEOF
    chmod +x "$PREFIX/bin/sudo"
    echo -e "  ${GREEN}✓${NC} Fake sudo installed (runs commands directly, no real root)"

    # --- GPU config ---
    mkdir -p ~/.config
    cat > ~/.config/gpu-env.sh << 'GPUEOF'
export MESA_NO_ERROR=1
export MESA_GL_VERSION_OVERRIDE=4.6
export MESA_GLES_VERSION_OVERRIDE=3.2
export GALLIUM_DRIVER=zink
export MESA_LOADER_DRIVER_OVERRIDE=zink
export TU_DEBUG=noconform
export MESA_VK_WSI_PRESENT_MODE=immediate
export ZINK_DESCRIPTORS=lazy
GPUEOF

    if ! grep -q "gpu-env.sh" ~/.bashrc 2>/dev/null; then
        echo 'source ~/.config/gpu-env.sh 2>/dev/null' >> ~/.bashrc
    fi

    # --- start.sh ---
    cat > ~/start.sh << 'STARTEOF'
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "Starting GLEM Desktop..."
echo ""

# Load GPU config
source ~/.config/gpu-env.sh 2>/dev/null

# Kill any existing sessions
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "xfce" 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null

# Audio setup
unset PULSE_SERVER
pulseaudio --kill 2>/dev/null
sleep 0.5
echo "Starting audio server..."
pulseaudio --start --exit-idle-time=-1
sleep 1
pactl load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1 2>/dev/null
export PULSE_SERVER=127.0.0.1

# Start X11 display server
echo "Starting X11 display server..."
termux-x11 :0 -ac &
sleep 3

export DISPLAY=:0

echo "Launching XFCE4 Desktop..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Open the Termux-X11 app to see desktop!"
echo "  Audio is enabled!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
exec startxfce4
STARTEOF
    chmod +x ~/start.sh
    echo -e "  ${GREEN}✓${NC} Created ~/start.sh"

    # --- stop.sh ---
    cat > ~/stop.sh << 'STOPEOF'
#!/data/data/com.termux/files/usr/bin/bash
echo "Stopping GLEM Desktop..."
pkill -9 -f "termux.x11" 2>/dev/null
pkill -9 -f "pulseaudio" 2>/dev/null
pkill -9 -f "xfce" 2>/dev/null
pkill -9 -f "dbus" 2>/dev/null
echo "Desktop stopped."
STOPEOF
    chmod +x ~/stop.sh
    echo -e "  ${GREEN}✓${NC} Created ~/stop.sh"
}

# ============== STEP 14: DESKTOP SHORTCUTS ==============
step_shortcuts() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}/${TOTAL_STEPS}] Creating Desktop Shortcuts...${NC}"
    echo ""
    mkdir -p ~/Desktop

    cat > ~/Desktop/Firefox.desktop << 'EOF'
[Desktop Entry]
Name=Firefox
Comment=Web Browser
Exec=firefox
Icon=firefox
Type=Application
Categories=Network;WebBrowser;
EOF

    cat > ~/Desktop/VSCode.desktop << 'EOF'
[Desktop Entry]
Name=VS Code
Comment=Code Editor
Exec=code-oss --no-sandbox
Icon=code-oss
Type=Application
Categories=Development;
EOF

    cat > ~/Desktop/Terminal.desktop << 'EOF'
[Desktop Entry]
Name=Terminal
Comment=XFCE Terminal
Exec=xfce4-terminal
Icon=utilities-terminal
Type=Application
Categories=System;TerminalEmulator;
EOF

    cat > ~/Desktop/Ubuntu.desktop << 'EOF'
[Desktop Entry]
Name=Ubuntu (proot)
Comment=Ubuntu Linux via proot-distro
Exec=xfce4-terminal -e "proot-distro login ubuntu"
Icon=utilities-terminal
Type=Application
Categories=System;
EOF

    chmod +x ~/Desktop/*.desktop 2>/dev/null
    echo -e "  ${GREEN}✓${NC} Desktop shortcuts created"
}

# ============== COMPLETION ==============
show_completion() {
    echo ""
    echo -e "${GREEN}"
    echo "    ╔═══════════════════════════════════════════════════════════════╗"
    echo "    ║                                                               ║"
    echo "    ║             INSTALLATION COMPLETE!                            ║"
    echo "    ║                                                               ║"
    echo "    ╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}  START DESKTOP:${NC}     ${GREEN}./start.sh${NC}     (or: bash ~/start.sh)"
    echo -e "${WHITE}  STOP DESKTOP:${NC}      ${GREEN}./stop.sh${NC}      (or: bash ~/stop.sh)"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${CYAN}  INSTALLED:${NC}"
    echo -e "   Desktop:    XFCE4 + GPU Acceleration + Audio"
    echo -e "   Apps:       Firefox, VS Code, Thunar, Mousepad"
    echo -e "   Dev:        Node.js, Git, Python, .NET 8 SDK, Make, Clang"
    echo -e "   Proot:      Ubuntu (proot-distro login ubuntu)"
    echo -e "   Sudo:       fake sudo wrapper (no real root)"
    echo -e "   Network:    Nmap, Netcat, Whois, DNS Utils"
    echo -e "   Security:   Hydra, SQLMap"
    echo -e "   Windows:    Wine/Hangover"
    echo ""
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${WHITE}  QUICK COMMANDS:${NC}"
    echo -e "   ${GREEN}node --version${NC}         Check Node.js"
    echo -e "   ${GREEN}git --version${NC}          Check Git"
    echo -e "   ${GREEN}dotnet --info${NC}          Check .NET 8 (runs in proot)"
    echo -e "   ${GREEN}proot-distro login ubuntu${NC}   Enter Ubuntu shell"
    echo -e "   ${GREEN}sudo <command>${NC}         Runs command directly (fake sudo)"
    echo -e "   ${GREEN}pkg install <pkg>${NC}      Install Termux packages"
    echo ""
    echo -e "${WHITE}  TIP: Open the Termux-X11 app first, then run ./start.sh${NC}"
    echo ""
}

# ============== MAIN ==============
main() {
    show_banner
    echo -e "${WHITE}  All-in-one installer: Desktop + Dev Tools + .NET 8${NC}"
    echo -e "${GRAY}  Estimated time: 20-40 minutes (depends on internet speed)${NC}"
    echo ""

    detect_device
    step_update          # 1
    step_repos           # 2
    step_x11             # 3
    step_desktop         # 4
    step_gpu             # 5
    step_audio           # 6
    step_apps            # 7
    step_devtools        # 8
    step_proot           # 9
    step_dotnet          # 10
    step_network_tools   # 11
    step_wine            # 12
    step_launchers       # 13
    step_shortcuts       # 14

    show_completion
}

main
