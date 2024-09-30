# DevOps Tool Installer/Uninstaller 🚀

![text](https://imgur.com/tP5o7Eu.png)

**This repository provides scripts to install/uninstall a wide range of DevOps tools on both Linux and Windows operating systems. These scripts are designed to make the installation and uninstallation process seamless and straightforward, catering to the needs of DevOps engineers and enthusiasts.**

## Features

- **User-Friendly Interface**: Interactive terminal menus for selecting installation or uninstallation actions on Windows.
- **Multi-OS Detection**: Automatically detects your Linux distribution or Windows version and performs appropriate actions.
- **Multi-Platform Support**: Install and uninstall DevOps tools on multiple Linux distributions (Ubuntu/Debian, CentOS/RHEL, Fedora) and Windows.
  - Install and uninstall essential DevOps tools with a single script.
  - Support for multiple Linux distributions: Ubuntu/Debian, CentOS/RHEL, Fedora.
  - Support for Windows operating systems.
  - Choose which tools to install or uninstall from a list of available options.
  - **New Features**:
    - Enhanced support for different Linux distributions and Windows versions.
    - Users can select their OS before installing or uninstalling tools, streamlining the process.

## DevOps Tools Included

- **Comprehensive Toolset**: Support for a wide range of tools including:
  - Docker 🐳
  - Kubernetes (kubectl) ☸️
  - Ansible 📜
  - Terraform 🌍
  - Jenkins 🏗️
  - AWS CLI ☁️
  - Azure CLI ☁️
  - Google Cloud SDK ☁️
  - Helm ⛵
  - Prometheus 📈
  - Grafana 📊
  - GitLab Runner 🏃‍♂️
  - HashiCorp Vault 🔐
  - HashiCorp Consul 🌐
  - Minikube ☸️
  - Istio 📦
  - OpenShift CLI ☸️
  - Packer 📦
  - Vagrant 📦

## Tool Preview

![text](https://imgur.com/kkUnTrk.png)

## Usage

After running the script, follow the on-screen prompts to select the tools you want to install or uninstall. The script will handle the rest based on your operating system and version.

### Linux Specific

- **Ubuntu/Debian**: Installs tools using `apt` package manager.
- **CentOS/RHEL**: Installs tools using `yum` package manager.
- **Fedora**: Installs tools using `dnf` package manager.

### Windows Specific

- **Chocolatey**: Utilizes `Chocolatey` package manager for installation and uninstallation of tools.

## Installation Options

You can install and run the DevOps Tool Installer in two ways: without cloning the repository or by cloning the repository. Choose the method that suits your needs.

### Method 1: Run the Installer Without Cloning the Repository

#### For Windows (PowerShell)

You can run the DevOps Tool Installer on your Windows machine directly with this one-liner:

```powershell
Invoke-Expression (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/NotHarshhaa/DevOps-Tool-Installer/master/install_devops_tools.ps1')
```

#### For Linux (Bash)

You can run the DevOps Tool Installer on your Linux machine directly with this one-liner:

```bash
bash <(curl -s https://raw.githubusercontent.com/NotHarshhaa/DevOps-Tool-Installer/master/install_devops_tools.sh)
```

### Method 2: Clone the Repository and Run the Installer

#### For Linux

1. Clone the repository:

    ```bash
    git clone https://github.com/NotHarshhaa/DevOps-Tool-Installer.git
    cd DevOps-Tool-Installer
    ```

2. Make the script executable:

    ```bash
    chmod +x install_devops_tools.sh
    ```

3. Run the script:

    ```bash
    ./install_devops_tools.sh
    ```

#### For Windows

1. Clone the repository:

    ```powershell
    git clone https://github.com/NotHarshhaa/DevOps-Tool-Installer.git
    cd DevOps-Tool-Installer
    ```

2. Run the script:

    ```powershell
    .\install_devops_tools.ps1
    ```

## Contribution

Feel free to contribute to this repository by submitting a pull request or opening an issue with suggestions or bug reports. Let's make this repository a go-to resource for DevOps tool installations!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Developed by [H A R S H H A A](https://github.com/NotHarshhaa).

## Contact

![Author Image](https://imgur.com/2j6Aoyl.png)

> [!NOTE]
> Join our [Telegram Community](https://t.me/prodevopsguy) for discussions and updates. Follow [ProDevOpsGuy](https://github.com/NotHarshhaa) for more DevOps content.

## Hit the Star! ⭐

**If you find this repository useful, please give it a star. Thanks!**
