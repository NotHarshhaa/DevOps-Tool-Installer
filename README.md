# 🚀 DevOps Tool Installer & Uninstaller  

![DevOps Tool Installer](https://imgur.com/QLlNazj.png)  

Easily **install and uninstall essential DevOps tools** on **Linux & Windows** with a single script! Whether you're a **DevOps Engineer, Cloud Enthusiast, or System Administrator**, this toolkit automates setup and cleanup of your environment — saving time and effort.  

---

![banner](https://imgur.com/5iUO7xf.png)

## 🔥 Why Use This?  

✅ **One-Click Installation & Uninstallation** – Set up or clean up all required DevOps tools effortlessly.  
✅ **Multi-OS Support** – Works on **Ubuntu, Debian, CentOS, Fedora, Arch, Alpine & Windows**.  
✅ **Auto-Detection** – Automatically detects your OS and applies the correct package manager.  
✅ **Interactive Checklist UI** – Select tools with `whiptail` (Linux) or menus (PowerShell).  
✅ **Advanced Cleanup** – Stops services, removes configs, logs, and binaries cleanly.  
✅ **Dry Run Mode** – Simulate uninstallation before applying changes.  
✅ **Timestamped Logs** – Every operation is logged for traceability.  
✅ **Universal Launchers** – Use a single `devops.ps1` / `devops.sh` to install or uninstall tools.  

---

## 🌟 Advanced Features

### 🔒 Security & Validation
- **Administrator Privilege Check** – Ensures proper permissions before execution
- **Package Verification** – Validates installations and configurations
- **Secure Update Mechanism** – Checks authenticity of updates
- **State Management** – Tracks tool installations and configurations

### 📊 Enhanced Logging & Monitoring
- **Comprehensive Logging System** – Detailed operation tracking with timestamps
- **Installation Status Tracking** – Real-time status monitoring
- **Error Handling** – Robust error capture and reporting
- **Operation History** – Maintains detailed history of all actions

### ⚡ Performance & Reliability
- **Parallel Installation Support** – Faster multi-tool installations
- **Timeout Management** – Prevents hanging operations
- **Auto-Recovery** – Handles failed installations gracefully
- **Resource Management** – Optimizes system resource usage

### 🔄 Update & Maintenance
- **Automatic Update Checks** – Notifies of new versions
- **Version Management** – Tracks and manages tool versions
- **Clean Uninstallation** – Complete removal of tools and configs
- **Backup & Restore** – Saves configurations before major changes

---

## 📌 Supported DevOps Tools  

### 🔹 Containerization & Orchestration  

✔️ Docker 🐳 | ✔️ Kubernetes (kubectl) ☸️ | ✔️ Helm ⛵ | ✔️ Minikube | ✔️ Istio | ✔️ OpenShift CLI  

### 🔹 Infrastructure as Code & Automation  

✔️ Ansible | ✔️ Terraform | ✔️ Packer | ✔️ Vagrant  

### 🔹 CI/CD & Monitoring  

✔️ Jenkins | ✔️ GitLab Runner | ✔️ Prometheus | ✔️ Grafana  

### 🔹 Cloud & Security  

✔️ AWS CLI | ✔️ Azure CLI | ✔️ Google Cloud SDK | ✔️ Vault | ✔️ Consul  

---

## 🛠️ Installation Guide  

### 🚀 Method 1: One-Liner (Quick Install)  

#### 📌 Windows (PowerShell):  

```powershell
iwr -useb https://raw.githubusercontent.com/NotHarshhaa/DevOps-Tool-Installer/master/devops.ps1 | iex
```

#### 📌 Linux (Bash):  

```bash
curl -s https://raw.githubusercontent.com/NotHarshhaa/DevOps-Tool-Installer/master/devops.sh | bash
```

🆕 These **combined launchers** (`devops.ps1` and `devops.sh`) automatically guide you to install or uninstall tools via an interactive prompt!

---

### 🖥️ Method 2: Clone the Repository  

#### 📌 Linux  

```bash
git clone https://github.com/NotHarshhaa/DevOps-Tool-Installer.git  
cd DevOps-Tool-Installer  
chmod +x devops.sh  
./devops.sh
```

#### 📌 Windows  

```powershell
git clone https://github.com/NotHarshhaa/DevOps-Tool-Installer.git  
cd DevOps-Tool-Installer  
.\devops.ps1  
```

---

## ❌ Uninstallation Guide  

🧹 This tool supports **clean uninstallation** with:  

- ✅ Interactive selection  
- ✅ Advanced cleanup (configs, services, logs)  
- ✅ Dry run mode for previewing changes  
- ✅ Timestamped logs saved in the `logs/` folder  

### 🔧 Linux & macOS  

Use the universal launcher:  

```bash
curl -s https://raw.githubusercontent.com/NotHarshhaa/DevOps-Tool-Installer/master/devops.sh | bash
```

---

### 🔧 Windows  

Use PowerShell launcher:  

```powershell
iwr -useb https://raw.githubusercontent.com/NotHarshhaa/DevOps-Tool-Installer/master/devops.ps1 | iex
```

---

🧭 **After running the launcher**, you'll be prompted to:  

- Select **Install Tools** or **Uninstall Tools**  
- Choose the tools from an interactive checklist  
- Run the selected operation with full logging

---

## 📋 What's New  

### 🆕 Latest Updates (v2.5.0)
- ✨ **Enhanced Logging System** – Comprehensive logging with mutex-based file access
- ✨ **Administrator Checks** – Strict privilege validation for secure execution
- ✨ **State Management** – Track installation status and configuration state
- ✨ **Parallel Installations** – Support for concurrent tool installations
- ✨ **Update Notifications** – Automatic checks for new versions
- ✨ **Improved Error Handling** – Better error capture and recovery
- ✨ **Installation Validation** – Verify successful tool installations
- ✨ **Resource Optimization** – Better system resource management
- ✨ **Timeout Controls** – Prevent hanging operations
- ✨ **Clean Uninstallation** – Improved cleanup procedures

### 🔄 Previous Updates
- ✅ **Universal Launchers** (`devops.sh` / `devops.ps1`) – Single entrypoint for operations
- ✅ **Advanced Uninstaller** with dry run support
- ✅ **Interactive Tool Selection** with categorized listings
- ✅ **Automated Logging** with timestamp organization

---

## 📝 How It Works  

1️⃣ Run the script (via quick method or cloned repo)  
2️⃣ Choose **Install** or **Uninstall**  
3️⃣ Select tools interactively  
4️⃣ Script detects your OS and uses the appropriate package manager  

### OS-Specific Package Managers  

| OS        | Package Manager |
|-----------|------------------|
| Ubuntu/Debian | `apt`        |
| CentOS/RHEL   | `yum`        |
| Fedora        | `dnf`        |
| Arch Linux    | `pacman`     |
| Alpine        | `apk`        |
| SUSE          | `zypper`     |
| Windows       | `choco`      |

---

## 🤝 Contribution  

Contributions are welcome!  

- 🐞 Report bugs by opening issues  
- ✨ Suggest new tools or features  
- 🔧 Submit PRs to improve install/uninstall logic  

---

## 🔗 Join the Community  

💬 **Telegram:** [Join our group](https://t.me/prodevopsguy)  
⭐ **GitHub:** [Follow me](https://github.com/NotHarshhaa)  
📖 **Blog:** [ProDevOpsGuy](https://blog.prodevopsguy.xyz)  
💼 **LinkedIn:** [Harshhaa Vardhan Reddy](https://www.linkedin.com/in/harshhaa-vardhan-reddy/)  

---

## ⭐ Show Your Support  

If this project saved you time, consider giving it a ⭐ on GitHub!  

![Follow Me](https://imgur.com/2j7GSPs.png)  
