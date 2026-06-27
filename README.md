# Fedora Post-Install Setup

This repository contains a unified, zero-dependency Bash script designed to automate post-installation configuration, system optimization, package management, and custom desktop/terminal modifications on a fresh installation of **Fedora Linux**.

By running this script, you can quickly bootstrap your Fedora desktop into a fully configured, high-performance workstation while strictly adhering to official Fedora system updates and package lifecycles.

---

## 🚀 Quick-Start One-Liner

On a fresh Fedora installation, open your terminal and run the following command to initiate the entire setup automatically:

```bash
curl -fsSL https://raw.githubusercontent.com/roguehunter7/fedora-setup-ansible/main/setup.sh | sudo bash
```

This single command fetches the setup script directly and executes it with root privileges to configure your system.

---

## What this Script Does

1. **DNF Speed Optimizations**: Configures `max_parallel_downloads=20`, `fastestmirror=True`, and `defaultyes=True` for both DNF and DNF5 to make package updates much faster.
2. **System-wide Package Upgrade**: Upgrades all pre-installed system packages to their latest versions to ensure stability, safety, and resolve potential version conflicts.
3. **Repository Configuration**:
   - Enables **RPM Fusion (Free & Non-Free)** repositories.
   - Enables the **Terra Repository** (maintained by Fyra Labs) to fetch tools like Starship and System76 Scheduler.
   - Configures the official repositories for **Visual Studio Code**, **Brave Browser**, **Google Chrome**, and the **Google Cloud CLI**.
   - Disables unused, limited third-party repositories (**NVIDIA** and **Steam** subsets) to prevent DNF metadata check bloat on AMD hardware.
4. **General Linux & Storage Optimizations**:
   - **Swappiness Tuning**: Configures `vm.swappiness = 10` via a custom sysctl drop-in file (`/etc/sysctl.d/99-swappiness.conf`) to optimize memory pages and reduce SSD swap wear.
   - **Btrfs Performance Tuning**: Safely updates `/etc/fstab` to append the `noatime` option to Btrfs subvolumes (`root` and `home`), reducing write amplification on SSDs/NVMes and remounts filesystems immediately.
5. **GNOME Customization & Desktop Tweaks**:
   - Installs **GNOME Tweaks** and the graphical **GNOME Extensions App**.
   - Installs and enables the popular **Dash to Dock** (dock UI) and **AppIndicator** (system tray icons) extensions.
   - Natively fetches, extracts, and activates the **Bluetooth Quick Connect** extension (allows connecting to paired Bluetooth devices directly from the Quick Settings menu).
   - Configures native window controls to **enable Minimize and Maximize buttons** (which are disabled by default in Fedora Workstation).
   - Sets the global system color scheme preference to **Dark Mode**.
6. **App Cleanup (Removal)**:
   - Uninstalls standard default applications: **Firefox** and **LibreOffice** (all core and interface packages), along with the installer WebUI helper package (`anaconda-webui`) and `unoconv` to prevent dependency conflicts.
7. **Multimedia Swap**:
   - Swaps out Fedora's restricted `ffmpeg-free` for full `ffmpeg` from RPM Fusion.
   - Installs the `@multimedia` package group (disabling weak dependencies and excluding PackageKit GStreamer plugins as recommended by RPM Fusion).
8. **Consolidated Package Installation**:
   - Downloads and installs all application and runtime packages in a **single DNF transaction** to maximize speed:
     - **Applications**: VLC, GNOME Boxes, Google Chrome, Brave Browser, Visual Studio Code.
     - **Runtimes & Build Tools**: Python 3 (including pip and development headers), Golang, Node.js, Java OpenJDK, and the Fedora **Development Tools** group (`make`, `gcc`, `git`, etc.).
     - **Container tools**: Distrobox.
     - **System tools**: flatpak, cabextract, mkfontscale, fontconfig.
9. **Performance Scheduler**:
   - Installs and enables the **System76 CPU Scheduler** (`system76-scheduler`) to prioritize foreground desktop processes and improve user interface responsiveness.
10. **Flatpak Integration**:
    - Ensures `flatpak` is installed, registers the **Flathub** remote repository, and removes the limited Fedora-centric Flatpak remote to ensure Flathub is your clean, exclusive source for Flatpaks.
    - Installs **OnlyOffice Desktop Editors** via Flatpak.
11. **Font Polish (Nerd Fonts & Microsoft Fonts)**:
    - Automatically downloads and extracts the official **Fira Code Nerd Font** into the user's local fonts directory (`~/.local/share/fonts/`) for terminal prompt icon support.
    - Downloads and installs the **Microsoft TrueType Core Fonts** (Arial, Times New Roman, Verdana, etc.) via the community installer.
    - Automatically rebuilds the system font cache so all new fonts are immediately available.
12. **Antigravity CLI**:
    - Downloads and installs the **Antigravity CLI (`agy`)** natively under the target user's directory (`~/.local/bin/agy`) using its official installer.
13. **Antigravity IDE**:
    - Registers a custom updater helper script (`/usr/local/bin/update-antigravity-ide`).
    - Resolves, downloads, extracts, and installs the latest Antigravity IDE Linux tarball (supporting x64 and ARM64 architectures) to `/opt/antigravity-ide`.
    - Creates launchers, icons, and GNOME menu shortcuts.
14. **Usability & Shell Customization (Zsh)**:
    - Installs **Zsh** and official shell plugins: **zsh-syntax-highlighting** and **zsh-autosuggestions**.
    - Sets your default system shell to **Zsh**.
    - Configures `~/.zshrc` to initialize the **Starship** shell prompt, expose the local binary path (`~/.local/bin`), and source the interactive shell plugins automatically.
    - Enables **Sudo Password Feedback** (shows asterisks `*` as you type passwords in the terminal).

---

## Alternative Execution (Manual)

If you prefer to download and run the script manually:

### Step 1: Clone the Repository
```bash
git clone https://github.com/roguehunter7/fedora-setup-ansible.git
cd fedora-setup-ansible
```

### Step 2: Make the Script Executable
```bash
chmod +x setup.sh
```

### Step 3: Run the Script
```bash
sudo ./setup.sh
```
