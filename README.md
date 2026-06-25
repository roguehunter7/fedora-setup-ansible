# Fedora Post-Install Setup with Ansible

This repository contains an Ansible playbook designed to automate post-installation configuration, system optimization, package management, and custom terminal interface modifications on a fresh installation of **Fedora Linux**. 

By running this playbook, you can quickly bootstrap your Fedora desktop into a fully configured, high-performance workstation while strictly adhering to official Fedora system updates and package lifecycles.

---

## What this Playbook Does

1. **DNF Speed Optimizations**: Configures `max_parallel_downloads=20`, `fastestmirror=True`, and `defaultyes=True` for both DNF and DNF5.
2. **Repository Configuration**:
   - Enables **RPM Fusion (Free & Non-Free)** repositories.
   - Enables the **Terra Repository** (maintained by Fyra Labs) to fetch tools like Starship and System76 Scheduler.
   - Configures the official repositories for **Visual Studio Code**, **Brave Browser**, and **Google Chrome**.
   - Disables unused, limited third-party repositories (**NVIDIA** and **Steam** subsets) to prevent DNF metadata check bloat on AMD hardware.
3. **General Linux & Storage Optimizations**:
   - **Swappiness Tuning**: Configures `vm.swappiness = 10` via a custom sysctl drop-in file (`/etc/sysctl.d/99-swappiness.conf`) to optimize memory pages and reduce SSD swap wear.
   - **Btrfs Performance Tuning**: Safely updates `/etc/fstab` to append the `noatime` option to Btrfs subvolumes (`root` and `home`), reducing write amplification on SSDs/NVMes and remounts filesystems immediately.
4. **App Cleanup (Removal)**:
   - Uninstalls standard default applications: **Firefox** and **LibreOffice** (all core and interface packages).
5. **Desktop Applications**:
   - Installs **OnlyOffice Desktop Editors** via Flatpak (Flathub).
   - Installs **Visual Studio Code**, **Brave Browser**, and **Google Chrome**.
   - Installs **VLC** media player and **GNOME Boxes** (virtualization tool).
6. **Developer Toolchains & Build Tools**:
   - Installs the official Fedora **Development Tools** group (`make`, `gcc`, `g++`, `git`, `patch`, etc.).
   - Installs developers runtimes: **Golang (Go)**, **Node.js**, **Python 3** (including pip and development headers), and the latest version of the **Java OpenJDK Runtime (JRE)**.
   - Installs **Distrobox** for managing containerized Linux development environments.
7. **Multimedia Support**:
   - Swaps out Fedora's restricted `ffmpeg-free` for full `ffmpeg` from RPM Fusion.
   - Installs the `@multimedia` package group (disabling weak dependencies and excluding PackageKit GStreamer plugins as recommended by RPM Fusion).
   - Installs common GStreamer codecs.
8. **System Scheduler & Performance**:
   - Installs and enables the **System76 CPU Scheduler** (`system76-scheduler`) to prioritize foreground desktop processes and improve user interface responsiveness.
9. **Flatpak Integration**:
   - Ensures `flatpak` is installed.
   - Registers the **Flathub** remote repository.
   - Removes the limited Fedora-centric Flatpak remote to ensure Flathub is your clean, exclusive source for Flatpaks.
10. **Font Polish (Nerd Fonts)**:
    - Automatically downloads and extracts the official **Fira Code Nerd Font** into the user's local fonts directory (`~/.local/share/fonts/`) and rebuilds the font cache so Starship icons display correctly.
11. **Usability & Shell Customization (Zsh)**:
    - Installs **Zsh** and official shell plugins: **zsh-syntax-highlighting** and **zsh-autosuggestions**.
    - Sets your default system shell to **Zsh**.
    - Configures `~/.zshrc` to initialize the **Starship** shell prompt and source the interactive shell plugins automatically.
    - Enables **Sudo Password Feedback** (shows asterisks `*` as you type passwords in the terminal).

---

## How to Run This Playbook

### Step 1: Install Ansible on Fedora
Ansible is available directly from the official Fedora repositories:
```bash
sudo dnf install ansible
```

### Step 2: Test the Playbook Syntax
Before running the playbook, verify its syntax:
```bash
ansible-playbook playbook.yml --syntax-check
```

### Step 3: Run the Playbook
Run the playbook using `ansible-playbook`. Since the tasks require root access to install packages and modify system configurations, we use the `--ask-become-pass` (or `-K`) flag to prompt for your `sudo` password:
```bash
ansible-playbook playbook.yml --ask-become-pass
```

---

## Learning Ansible: Concepts Used in this Project

Here is a breakdown of the Ansible concepts implemented in this codebase:

### 1. The Inventory (`inventory.ini`)
An Ansible inventory file lists the systems (hosts) you want to manage. Typically, these are remote servers accessed via SSH.
In our `inventory.ini`, we define:
```ini
[localhost]
localhost ansible_connection=local
```
This tells Ansible that the system being configured is the local machine (`localhost`), and to use the `local` connection plugin directly rather than attempting SSH loopback.

### 2. Plays and Playbooks (`playbook.yml`)
*   **Playbook**: A YAML file containing one or more *Plays*.
*   **Play**: Links a group of hosts (e.g. `hosts: localhost`) to a set of *Tasks*.
*   **Become**: Setting `become: yes` instructs Ansible to escalate privileges using `sudo` to run the tasks.

### 3. Tasks and Modules
A play contains a list of **tasks** executed sequentially. Each task calls a specific **module** to do the work. Modules are reusable, standalone scripts. The modules we used include:
*   `ansible.builtin.user`: Looks up or manages user accounts. We register its output to find the home directory of the regular (non-root) user and use it to change the user's login shell.
*   `ansible.builtin.ini_file`: Modifies configuration settings in INI-formatted files (like `dnf.conf` or `fedora-workstation-repositories.repo`).
*   `ansible.builtin.dnf`: Package manager module for Fedora to install, update, or swap packages (including support for group installs via `@` prefixes and setting specific options like `install_weak_deps`).
*   `ansible.builtin.yum_repository`: Configures repository definitions under `/etc/yum.repos.d/`.
*   `ansible.builtin.systemd`: Manages systemd services (starts and enables `system76-scheduler`).
*   `ansible.builtin.replace`: Finds regular expression patterns inside files (like `/etc/fstab`) and modifies matches safely and idempotently.
*   `ansible.builtin.unarchive`: Automatically fetches compressed archives (`.tar.xz` or `.zip`) from remote URLs, copies them, and extracts them to a destination directory.
*   `ansible.builtin.blockinfile`: Writes a structured block of multiple lines into configuration files (like `~/.zshrc`), wrapping them in comments to ensure idempotency.
*   `ansible.builtin.lineinfile`: Safely appends lines to text files (like inserting Starship config inside `.bashrc`).
*   `ansible.builtin.copy`: Copies a string or file to a destination (like writing the sudo config).

### 4. Idempotency
One of Ansible's most powerful features is **idempotency**. An idempotent task only makes changes to the system if it is not already in the desired state.
*   If a package is already installed, Ansible reports `ok` and does nothing.
*   If the configuration line is already in `.bashrc`, it won't add it again.
*   You can run this playbook multiple times safely; only missing items will be updated.

### 5. Facts (`gather_facts: yes`)
When Ansible runs a playbook, it starts by "gathering facts". Facts are system variables (like IP addresses, OS name, version number).
In our playbook, we use `{{ ansible_distribution_major_version }}` to automatically fetch the RPM Fusion packages corresponding to your exact Fedora version.

### 6. The Sudo User Gotcha (`ansible_env.SUDO_USER`)
When you run a playbook as root via `become: yes`, Ansible runs commands as the root user. If you use the root home folder (`/root`), you won't configure your own personal user files.
To solve this, we query the environment variable `ansible_env.SUDO_USER` (the user who ran the `sudo` command) to find your real username, and use `ansible.builtin.user` to fetch your actual home directory `/home/username`. This ensures your user shell configurations are correctly modified.
