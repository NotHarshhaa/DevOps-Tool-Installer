# 📋 Changelog

All notable changes to **DevOps Tool Installer** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project tries to adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### ✨ New Features

- 🩺 **`doctor` health check** (new launcher action, Windows & Linux) – read-only environment diagnostics with CI-friendly exit codes: package managers, disk space, free RAM, network reachability, helper tools (`jq`/`curl`), state-file integrity, and log-directory writability; exits `1` only on hard failures
- 👥 **Tool profiles** – `devops.ps1 export` / `devops.sh export` write the installed tool set to a shareable `profiles/devops_profile.txt` (with `[windows]` / `[linux]` sections); the installers re-apply it via `install_devops_tools.ps1 -Profile <file>` and `install_devops_tools.sh --from <file>` — workstation setup as code, platform-aware
- ⬆️ **Upgrade mode** – new `upgrade` launcher action and installer flags (`-Upgrade` on Windows, `-U/--upgrade` on Linux) upgrade *only already installed tools*: missing tools are skipped on Linux, and on Windows `choco upgrade`/`winget upgrade` is used with automatic fallback to install for non-tracked packages
- 🔓 **Read-only installer modes run without root (Linux)** – `-h/--help`, `-l/--list` and `-d/--dry-run` no longer require elevation (root is still enforced for real installs), matching the PowerShell installer's behavior

---

## [3.5.x] - Automation & Reliability Release

### ✨ New Features

- 🤖 **Full CLI / automation support** – every script now runs non-interactively: launcher actions (`install`, `uninstall`, `update`, `status`, `info`, `verify`, `logs`), plus flags like `-Install`, `-All`, `-DryRun`, `-List`, `-Force`, `-j N` on the installers and uninstallers
- 🔍 **Verify Installed Tools** (new launcher option 6 + `verify` action) – re-checks every tool recorded in the state file against `PATH` and reports `[OK]` / `[MISSING]`
- 📜 **View Recent Logs** (new launcher option 7 + `logs` action) – tails the manager, installer, and uninstaller logs in one place
- 🔢 **Multi-select & range menus** – pick tools by number (`3`), range (`1-5`), list (`2,4`) or `all`; the Linux catalog is sorted so menu numbers are stable across runs
- ♻️ **Idempotent installs** (Windows) – tools that already validate as installed are skipped automatically; use `-Reinstall` to force a reinstall
- 🔁 **Retry failed installations** – `--retry-failed` on Linux (driven by the state file) and a retry prompt after the summary on Windows, with the state file and summary updated accordingly
- 🧪 **Dry run everywhere** – `install_devops_tools.sh -d` and `install_devops_tools.ps1 -DryRun` now cover both directions (install *and* uninstall) on both platforms, making zero changes to the system
- 🌱 **Privilege checks refined** – Administrators/root are only required for actions that change the system; read-only actions work as a normal user (also fixed a 1000× wrong "Free RAM" readout in the Windows system info dashboard)
- 📝 **Log hygiene** – 10 MB log rotation in the launchers and PowerShell installer, plus newest-5 cleanup for per-tool installer logs
- 🙈 **Git hygiene** – added a `.gitignore` for runtime artifacts (`logs/`, `state/`, `backups/`, `config/`, `*.log`)
- 📚 **`-List` / `-l` catalog mode** – print the complete tool catalog (with installed status on the uninstaller) without any prompts

### 🐛 Stability & Correctness Fixes

- 🐧 **Fixed apt/apk installs never running** – `if ! sudo apt-get update && sudo apt-get install ...` negated only the update (bash precedence), so packages were never installed when the update succeeded
- 🐞 **Fixed failed installs reported as success** – `timeout ... | tee` masked real exit codes; now uses `PIPESTATUS` + `set -o pipefail`, and parallel install subshells propagate their true status so success/failure counters are accurate
- 💾 **Atomic state file writes** – `flock`-based locking plus unique temp files stop parallel installs from corrupting `devops_state.json`; dry-run no longer writes any state
- 🎯 **Fixed package-name mismatches (Windows uninstaller)** – now targets the same Chocolatey packages the installer uses (`gcloudsdk`, `istioctl`), aligned tool labels, and added the missing `Git`
- 📦 **Fixed Chocolatey bootstrap** – the install script was saved as `.tmp` and could not be executed via `&`; also refreshed `PATH` after installs and accepted MSI "reboot required" exit codes (3010/1641) as success
- 🗜️ **Fixed self-update extraction (Windows)** – GitHub archives extract to `DevOps-Tool-Installer-v<version>`; the updater now detects the extracted root and no longer backs up its own backups (Linux: excludes `backups/`, `logs/`, `state/`)
- 🔐 **Update version parsing hardened** – non-semver tags no longer crash `[version]` casts or the semver comparison
- 📸 **Fixed choco package detection** – matcher now understands `--limit-output` `pkg|version` lines, so installed tools are detected correctly (was reporting everything "Not Found")
- 🗑️ **Linux uninstaller** – now purges apt-installed `kubectl`, portable log-cleanup (no GNU-only `head -n -N`), and `--force` skips the "tool in use" prompt
- ⚙️ **Linux installer** – `install_base_requirements` branches per package manager instead of hardcoding `apt-get`; removed `sudo` for a root-only context (and the broken unquoted `dnf check-update || true` string)
- 🧯 **Hardened Chocolatey version checks** – guarded `choco --version` parsing against unexpected output
- 🖥️ **Windows launcher hardening** – graceful `ReadKey` fallback in ISE/CI hosts, guarded extraction of update archives, and sub-script exit codes are reported instead of always "completed successfully"

---

## [3.5.0] - Major Stability & UX Release

- 🚀 **Option 5 System Information fully implemented** in PowerShell with detailed OS, CPU, RAM, disk, package managers, and network checks
- 🛠️ **PowerShell Installer Progress Tracking & Summary** – Displays interactive progress `[N/Total]` and a final summary table of installation status
- 🔴 **PowerShell State File Mismatches Resolved** – Aligned state file location at repository root so the installation status dashboard displays correctly
- 🔴 **PowerShell Mutex Releases Hardened** – Fixed crash risks by validating mutex acquisition before releasing
- 🔴 **Bash Uninstall Command Execution Restored** – Replaced overly restrictive pattern verification with secure `bash -c` executions to allow uninstall commands to run correctly
- 🔄 **Updated Tool Versions & repos** – Upgraded Kubernetes CLI to v1.31, Terraform to HashiCorp's official APT repository, Istio to 1.22.3, Prometheus to v2.53.1, and deprecated Google Cloud SDK apt-key methods with modern signed-by keyrings
- 🔄 **Chocolatey 2.x compatibility updates** – Updated list/uninstall flags in PowerShell scripts to work natively on modern Chocolatey instances

---

## [3.0.0] - Security Hardening Release

- 🛡️ **Critical Security Fixes** – Eliminated command injection vulnerabilities in all scripts
- 🔐 **Input Validation** – Comprehensive protection against malicious command patterns
- 🚫 **Safe Command Execution** – Replaced `eval` and `Invoke-Expression` with secure alternatives
- ⏱️ **Mutex Deadlock Prevention** – Timeout-based handling prevents script hanging
- 💾 **Memory Leak Prevention** – Automatic cleanup of temporary resources and timeouts
- 🔒 **TLS 1.2 Enforcement** – Secure network connections with modern encryption standards
- 📝 **Enhanced Logging** – Mutex-based file access with proper error handling
- 🛠️ **Administrator Checks** – Strict privilege validation for secure execution
- 📊 **State Management** – Track installation status and configuration state with JSON persistence
- 🚀 **Parallel Installations** – Support for concurrent tool installations with job limiting
- 🔔 **Update Notifications** – Automatic checks for new versions with GitHub API integration
- 🚨 **Improved Error Handling** – Better error capture with specific messages and recovery options
- ✅ **Installation Validation** – Verify successful tool installations with version checking
- 💾 **Resource Optimization** – Better system resource management and cleanup
- ⏱️ **Timeout Controls** – Prevent hanging operations with configurable timeouts
- 🧹 **Clean Uninstallation** – Improved cleanup procedures with verification

---

## [2.5.0]

- ✅ **Universal Launchers** (`devops.sh` / `devops.ps1`) – Single entrypoint for operations
- ✅ **Advanced Uninstaller** with dry run support
- ✅ **Interactive Tool Selection** with categorized listings
- ✅ **Automated Logging** with timestamp organization
