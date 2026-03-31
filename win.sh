# Install dependencies
pkg install git sassc

# --- GTK + Window Manager Theme ---
cd ~
git clone https://github.com/yeyushengfan258/Win11-gtk-theme.git
cd Win11-gtk-theme
# Dark mode with rounded corners:
./install.sh -c dark --tweaks round
# Or light mode:
# ./install.sh -c light --tweaks round

# --- Icon Theme ---
cd ~
git clone https://github.com/yeyushengfan258/Win11-icon-theme.git
cd Win11-icon-theme
./install.sh

# --- Fluent Cursors ---
cd ~
git clone https://github.com/vinceliuice/Fluent-cursors.git
cd Fluent-cursors
./install.sh

# --- Windows 11 wallpaper ---
mkdir -p ~/Pictures
cd ~/Pictures
# Grab a Win11-style bloom wallpaper (or use your own)
wget -O wallpaper.jpg "https://raw.githubusercontent.com/ArmynC/windows-11-wallpapers/main/Wallpapers/Windows%2011/img0.jpg" 2>/dev/null || true
