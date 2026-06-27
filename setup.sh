#!/usr/bin/env bash
# ==============================================================================
# Fedora Post-Install Setup Bootstrapper
# ==============================================================================
# This script automates system optimization, repository configurations, package
# management, GNOME customizations, and development tool installs on Fedora.
# ==============================================================================

set -euo pipefail

# Ensure script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run with root privileges (sudo)." >&2
    exit 1
fi

# ==============================================================================
# USER DISCOVERY
# ==============================================================================
TARGET_USER="${SUDO_USER:-$(whoami)}"
if [ "$TARGET_USER" = "root" ]; then
    echo "Warning: Running as root directly. Settings and dotfiles will be applied to /root."
    TARGET_HOME="/root"
    TARGET_GROUP="root"
else
    TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
    TARGET_GROUP=$(id -gn "$TARGET_USER")
fi

echo "--> Target User: $TARGET_USER"
echo "--> Target Home: $TARGET_HOME"

# ==============================================================================
# PACKAGE MANAGER OPTIMIZATIONS (DNF / DNF5) & SYSTEM UPGRADE
# ==============================================================================
configure_dnf_speedups() {
    local conf_file="$1"
    if [ -f "$conf_file" ]; then
        echo "--> Configuring DNF speedups in $conf_file..."
        for opt in max_parallel_downloads=20 defaultyes=True fastestmirror=True; do
            key="${opt%%=*}"
            val="${opt#*=}"
            if grep -q "^\[main\]" "$conf_file"; then
                if grep -q "^$key[[:space:]]*=" "$conf_file"; then
                    sed -i "s/^$key[[:space:]]*=.*/$key = $val/" "$conf_file"
                else
                    sed -i "/^\[main\]/a $key = $val" "$conf_file"
                fi
            else
                echo -e "[main]\n$key = $val" >> "$conf_file"
            fi
        done
        chmod 0644 "$conf_file"
    fi
}

configure_dnf_speedups "/etc/dnf/dnf.conf"
configure_dnf_speedups "/etc/dnf5/dnf.conf"

echo "--> Upgrading all system packages..."
dnf upgrade -y

# ==============================================================================
# SYSTEM OPTIMIZATIONS (SWAPPINESS & BTRFS)
# ==============================================================================
echo "--> Configuring VM swappiness to 10..."
echo "vm.swappiness = 10" > /etc/sysctl.d/99-swappiness.conf
chmod 0644 /etc/sysctl.d/99-swappiness.conf
sysctl -p /etc/sysctl.d/99-swappiness.conf >/dev/null || true

echo "--> Enabling noatime mount option for Btrfs volumes in /etc/fstab..."
python3 -c "
import re
with open('/etc/fstab', 'r') as f:
    content = f.read()
new_content = re.sub(r'(?m)^(\S+\s+\S+\s+btrfs\s+)(?!.*noatime)(\S+)(.*)$', r'\g<1>\g<2>,noatime\3', content)
with open('/etc/fstab', 'w') as f:
    f.write(new_content)
"
echo "--> Remounting root filesystem..."
mount -o remount / || true

# ==============================================================================
# REPOSITORIES SETUP
# ==============================================================================
FEDORA_VERSION=$(rpm -E %fedora)
echo "--> Installing RPM Fusion Free and Nonfree repositories..."
dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm"
dnf install -y "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm"

echo "--> Adding third-party repositories..."
# Terra repository
cat <<EOF > /etc/yum.repos.d/terra.repo
[terra]
name=Terra \$releasever
baseurl=https://repos.fyralabs.com/terra\$releasever
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://repos.fyralabs.com/terra\$releasever/key.asc
skip_if_unavailable=1
enabled=1
EOF

# VS Code repository
cat <<EOF > /etc/yum.repos.d/vscode.repo
[vscode]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
enabled=1
EOF

# Brave Browser repository
cat <<EOF > /etc/yum.repos.d/brave-browser.repo
[brave-browser]
name=Brave Browser
baseurl=https://brave-browser-rpm-release.s3.brave.com/x86_64/
gpgcheck=1
gpgkey=https://brave-browser-rpm-release.s3.brave.com/brave-core.asc
enabled=1
EOF

# Google Chrome repository
cat <<EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=Google Chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
enabled=1
EOF

# Google Cloud CLI repository
cat <<EOF > /etc/yum.repos.d/google-cloud-cli.repo
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
enabled=1
EOF

# Disable unused workstation repositories if file exists
WORKSTATION_REPOS="/etc/yum.repos.d/fedora-workstation-repositories.repo"
if [ -f "$WORKSTATION_REPOS" ]; then
    echo "--> Disabling unused Workstation repositories (NVIDIA & Steam)..."
    python3 -c "
import configparser
config = configparser.ConfigParser(strict=False)
config.read('$WORKSTATION_REPOS')
for section in ['rpmfusion-nonfree-nvidia-driver', 'rpmfusion-steam']:
    if config.has_section(section):
        config.set(section, 'enabled', '0')
with open('$WORKSTATION_REPOS', 'w') as f:
    config.write(f)
"
fi

# ==============================================================================
# REMOVE UNWANTED DEFAULT APPLICATIONS
# ==============================================================================
echo "--> Checking and uninstalling Firefox, LibreOffice, and conflicting packages..."
PACKAGES_TO_REMOVE=$(rpm -qa --qf "%{NAME}\n" | grep -E '^(firefox|libreoffice|unoconv|anaconda-webui)' | tr '\n' ' ')
if [ -n "$PACKAGES_TO_REMOVE" ]; then
    echo "Removing packages: $PACKAGES_TO_REMOVE"
    dnf remove -y $PACKAGES_TO_REMOVE
else
    echo "No matching packages to remove."
fi

# ==============================================================================
# APPLICATIONS & MULTIMEDIA SWAP (MUST RUN INDEPENDENTLY FOR ALLOWERASING)
# ==============================================================================
echo "--> Swapping ffmpeg-free with full ffmpeg..."
dnf install -y ffmpeg --allowerasing

echo "--> Installing RPM Fusion multimedia group..."
dnf group install -y "multimedia" --setopt=install_weak_deps=False --exclude=PackageKit-gstreamer-plugin

# ==============================================================================
# CONSOLIDATED PACKAGE INSTALLATION (FASTER TRANSACTION RESOLUTION)
# ==============================================================================
echo "--> Installing all applications, runtimes, development tools, and dependencies..."
dnf install -y \
  @development-tools \
  vlc gnome-boxes gstreamer1-plugins-ugly gstreamer1-plugins-bad-freeworld gstreamer1-libav lame-libs \
  code brave-browser google-chrome-stable google-cloud-cli libxcrypt-compat \
  golang nodejs python3 python3-pip python3-devel java-latest-openjdk distrobox zsh zsh-syntax-highlighting zsh-autosuggestions \
  gnome-tweaks gnome-extensions-app gnome-shell-extension-dash-to-dock gnome-shell-extension-appindicator \
  system76-scheduler flatpak cabextract mkfontscale fontconfig

# ==============================================================================
# GNOME CONFIGURATIONS
# ==============================================================================
if [ "$TARGET_USER" != "root" ]; then
    echo "--> Installing Bluetooth Quick Connect GNOME extension..."
    sudo -u "$TARGET_USER" python3 - <<'PY'
import urllib.request, json, os, subprocess, zipfile
try:
    shell_ver = subprocess.check_output(["gnome-shell", "--version"]).decode().split()[-1]
    url = f"https://extensions.gnome.org/extension-info/?pk=1401&shell_version={shell_ver}"
    req = urllib.request.urlopen(url)
    data = json.loads(req.read().decode())
    download_url = "https://extensions.gnome.org" + data["download_url"]
    uuid = data["uuid"]
    ext_dir = os.path.expanduser(f"~/.local/share/gnome-shell/extensions/{uuid}")
    os.makedirs(ext_dir, exist_ok=True)
    zip_path, _ = urllib.request.urlretrieve(download_url)
    with zipfile.ZipFile(zip_path, "r") as zip_ref:
        zip_ref.extractall(ext_dir)
    os.remove(zip_path)
    print(f"Bluetooth Quick Connect ({uuid}) installed.")
except Exception as e:
    print(f"Error installing extension: {e}")
PY

    echo "--> Enabling GNOME Shell Extensions..."
    for ext in dash-to-dock@micxgx.gmail.com appindicatorsupport@rgcjonas.gmail.com bluetooth-quick-connect@bjarosze.github.io; do
        sudo -u "$TARGET_USER" dbus-run-session gnome-extensions enable "$ext" || true
    done

    echo "--> Configuring GNOME preferences (Window button layout and Dark Mode)..."
    sudo -u "$TARGET_USER" dbus-run-session gsettings set org.gnome.desktop.wm.preferences button-layout "appmenu:minimize,maximize,close" || true
    sudo -u "$TARGET_USER" dbus-run-session gsettings set org.gnome.desktop.interface color-scheme "prefer-dark" || true
fi

# ==============================================================================
# PERFORMANCE SCHEDULER & FLATPAK
# ==============================================================================
echo "--> Enabling System76 CPU Scheduler..."
systemctl enable --now system76-scheduler

echo "--> Setting up Flatpaks (OnlyOffice)..."
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
if flatpak remote-list | grep -q '^fedora'; then
    flatpak remote-delete fedora || true
fi
flatpak install -y flathub org.onlyoffice.desktopeditors || true

# ==============================================================================
# FONTS (NERD FONTS & MICROSOFT CORE FONTS)
# ==============================================================================
if [ "$TARGET_USER" != "root" ]; then
    echo "--> Creating local fonts directory..."
    FONT_DIR="$TARGET_HOME/.local/share/fonts"
    mkdir -p "$FONT_DIR"
    chown "$TARGET_USER":"$TARGET_GROUP" "$FONT_DIR"
    chmod 0755 "$FONT_DIR"

    echo "--> Downloading and extracting Fira Code Nerd Font..."
    sudo -u "$TARGET_USER" curl -fsSL -o "$TARGET_HOME/FiraCode.tar.xz" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.tar.xz
    sudo -u "$TARGET_USER" tar -xf "$TARGET_HOME/FiraCode.tar.xz" -C "$FONT_DIR"
    rm -f "$TARGET_HOME/FiraCode.tar.xz"
fi

echo "--> Installing Microsoft Core Fonts installer..."
if ! rpm -q msttcore-fonts-installer >/dev/null 2>&1; then
    rpm -i --nodeps --nodigest https://downloads.sourceforge.net/project/mscorefonts2/rpms/msttcore-fonts-installer-2.6-1.noarch.rpm || true
fi

echo "--> Rebuilding font cache..."
fc-cache -f || true

# ==============================================================================
# ANTIGRAVITY CLI & IDE INSTALLATION
# ==============================================================================
if [ "$TARGET_USER" != "root" ]; then
    echo "--> Installing Antigravity CLI..."
    sudo -u "$TARGET_USER" bash -c "curl -fsSL https://antigravity.google/cli/install.sh | bash"
fi

echo "--> Setting up Antigravity IDE installer script..."
cat <<'EOF' > /usr/local/bin/update-antigravity-ide
#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
	echo "Run with sudo: sudo update-antigravity-ide" >&2
	exit 1
fi

download_page="https://antigravity.google/download"
install_root="/opt/antigravity-ide"
command_link="/usr/local/bin/antigravity-ide"
desktop_file="/usr/share/applications/antigravity-ide.desktop"
icon_file="/usr/share/icons/hicolor/512x512/apps/antigravity-ide.png"

case "$(uname -m)" in
x86_64 | amd64) platform="linux-x64" ;;
aarch64 | arm64) platform="linux-arm" ;;
*)
	echo "Unsupported architecture: $(uname -m)" >&2
	exit 1
	;;
esac

for required_command in curl tar python3; do
	if ! command -v "$required_command" >/dev/null 2>&1; then
		echo "$required_command is required to install Antigravity IDE." >&2
		exit 1
	fi
done

if [ -L "$command_link" ]; then
	command_target=$(readlink -f "$command_link" || true)
	case "$command_target" in
	"$install_root"/*) ;;
	*)
		echo "$command_link points to $command_target. Move it before rerunning this helper." >&2
		exit 1
		;;
	esac
elif [ -e "$command_link" ]; then
	echo "$command_link exists and is not a symlink. Move it before rerunning this helper." >&2
	exit 1
fi

tmp_parent="${TMPDIR:-/var/tmp}"
mkdir -p "$tmp_parent"
tmpdir=$(mktemp -d "$tmp_parent/antigravity-ide.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT
download_html="$tmpdir/download.html"
download_js="$tmpdir/download.js"
archive="$tmpdir/Antigravity-IDE.tar.gz"
archive_list="$tmpdir/archive-list.txt"

curl -fsSL --compressed --retry 3 -o "$download_html" "$download_page"
main_js_url=$(
	python3 - "$download_html" "$download_page" <<'PY'
import re
import sys
from pathlib import Path
from urllib.parse import urljoin

html = Path(sys.argv[1]).read_text()
page_url = sys.argv[2]
matches = re.findall(r'(?:src|href)="([^"]*main-[^"]+\.js)"', html)
if not matches:
    raise SystemExit("Could not find the Antigravity download bundle")
print(urljoin(page_url, matches[-1]))
PY
)

curl -fsSL --compressed --retry 3 -o "$download_js" "$main_js_url"
download_fields=$(
	python3 - "$download_js" "$platform" <<'PY'
import re
import sys
from pathlib import Path

bundle = Path(sys.argv[1]).read_text(errors="replace")
platform = sys.argv[2]

urls = re.findall(r'href:"(https?://[^"]*/' + re.escape(platform) + r'/Antigravity(?:%20|\s)IDE\.tar\.gz)"', bundle)
if not urls:
    raise SystemExit(f"Could not find an IDE download URL for {platform}")

url = urls[-1]
version_match = re.search(r'/stable/([^/]+)/', url)
if not version_match:
    raise SystemExit("Could not parse Antigravity IDE version from download URL")

print(version_match.group(1).split("-", 1)[0], url)
PY
)
read -r version download_url <<<"$download_fields"

if [ -z "$version" ] || [ -z "$download_url" ]; then
	echo "Could not parse the Antigravity IDE download page." >&2
	exit 1
fi

expected_top_dir="Antigravity IDE"
expected_target="$install_root/$expected_top_dir/antigravity-ide"
installed_version=$(cat "$install_root/.linuxcapable-version" 2>/dev/null || true)
desktop_matches=no
if [ -f "$desktop_file" ] &&
	grep -q '^Icon=antigravity-ide$' "$desktop_file" &&
	grep -q '^StartupWMClass=antigravity-ide$' "$desktop_file"; then
	desktop_matches=yes
fi
if [ "$installed_version" = "$version" ] &&
	[ -x "$expected_target" ] &&
	[ -L "$command_link" ] &&
	[ "$(readlink -f "$command_link")" = "$expected_target" ] &&
	[ "$desktop_matches" = yes ] &&
	[ -f "$icon_file" ]; then
	printf 'Antigravity IDE %s is already installed at %s\n' "$version" "$install_root/$expected_top_dir"
	exit 0
fi

printf 'Downloading Antigravity IDE %s for %s...\n' "$version" "$platform"
curl -fsSL --retry 3 -o "$archive" "$download_url"
tar -tzf "$archive" >"$archive_list"
top_dir=$(sed -n '1{s#/.*##;p;q}' "$archive_list")
if [ "$top_dir" != "$expected_top_dir" ]; then
	echo "Unexpected archive directory: $top_dir" >&2
	exit 1
fi

tar -xzf "$archive" -C "$tmpdir"
if [ ! -x "$tmpdir/$top_dir/antigravity-ide" ]; then
	echo "The Antigravity IDE launcher was not found in the archive." >&2
	exit 1
fi

icon_source="$tmpdir/$top_dir/resources/app/resources/linux/code.png"
if [ ! -f "$icon_source" ]; then
	echo "The Antigravity IDE icon was not found in the archive." >&2
	exit 1
fi

rm -rf "${install_root}.new"
mkdir -p "${install_root}.new"
cp -a "$tmpdir/$top_dir" "${install_root}.new/"
printf '%s\n' "$version" >"${install_root}.new/.linuxcapable-version"
if [ -d "$install_root" ]; then
	rm -rf "${install_root}.previous"
	mv "$install_root" "${install_root}.previous"
fi
mv "${install_root}.new" "$install_root"
ln -sfn "$install_root/$top_dir/antigravity-ide" "$command_link"

mkdir -p "$(dirname "$icon_file")"
install -m 0644 "$icon_source" "$icon_file"

tee "$desktop_file" >/dev/null <<DESKTOP
[Desktop Entry]
Name=Antigravity IDE
Comment=Google Antigravity IDE
Exec=$command_link %U
Icon=antigravity-ide
Terminal=false
Type=Application
Categories=Development;IDE;
MimeType=x-scheme-handler/antigravity-ide;application/x-antigravity-workspace;
StartupNotify=true
StartupWMClass=antigravity-ide
DESKTOP

if command -v restorecon >/dev/null 2>&1; then
	restorecon -R "$install_root" "$command_link" "$desktop_file" "$icon_file" 2>/dev/null || true
fi

if command -v update-desktop-database >/dev/null 2>&1; then
	update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi

if command -v gtk-update-icon-cache >/dev/null 2>&1; then
	gtk-update-icon-cache -q /usr/share/icons/hicolor 2>/dev/null || true
fi

printf 'Installed Antigravity IDE %s at %s\n' "$version" "$install_root/$top_dir"
EOF

chmod 0755 /usr/local/bin/update-antigravity-ide
echo "--> Executing Antigravity IDE installation helper..."
/usr/local/bin/update-antigravity-ide

# ==============================================================================
# SHELL & USABILITY POLISH
# ==============================================================================
if [ "$TARGET_USER" != "root" ]; then
    echo "--> Changing user shell to Zsh..."
    usermod -s /bin/zsh "$TARGET_USER"

    echo "--> Configuring Starship prompt in .bashrc..."
    if ! grep -q 'starship init bash' "$TARGET_HOME/.bashrc"; then
        echo 'eval "$(starship init bash)"' >> "$TARGET_HOME/.bashrc"
    fi

    echo "--> Configuring Zsh options and plugins in .zshrc..."
    ZSHRC_FILE="$TARGET_HOME/.zshrc"
    if [ ! -f "$ZSHRC_FILE" ]; then
        touch "$ZSHRC_FILE"
    fi

    # Append config block idempotently
    python3 -c "
import os, re
path = '$ZSHRC_FILE'
block = '''# BEGIN SETUP BLOCKS
# Initialize Starship Prompt
eval \"\$(starship init zsh)\"

# Enable syntax highlighting and autosuggestions from DNF packages
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh

# Ensure local bin is in PATH (required for agy CLI)
export PATH=\"\$HOME/.local/bin:\$PATH\"

# Sane Zsh options
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# Custom alias to easily reload zsh config
alias reload=\"source ~/.zshrc\"
# END SETUP BLOCKS'''

content = ''
if os.path.exists(path):
    with open(path, 'r') as f:
        content = f.read()

content = re.sub(r'# BEGIN SETUP BLOCKS.*?# END SETUP BLOCKS', '', content, flags=re.DOTALL)
content = content.rstrip('\n') + '\n\n' + block + '\n'

with open(path, 'w') as f:
    f.write(content)
"
    chown "$TARGET_USER":"$TARGET_GROUP" "$ZSHRC_FILE"
fi

echo "--> Enabling sudo password feedback..."
echo "Defaults pwfeedback" > /etc/sudoers.d/pwfeedback
chmod 0440 /etc/sudoers.d/pwfeedback

echo "=============================================================================="
echo "Setup complete! Please restart your system or log out and back in to apply all updates."
echo "=============================================================================="
