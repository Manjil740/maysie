# 🤖 Maysie — Your Linux AI Assistant

> **A privacy‑respecting, locally‑aware AI assistant for Linux.**
> Always ready. Always local. Powerful—but safe.

---

## ✨ Overview

**Maysie** runs quietly in the background on your Linux desktop and springs to life with a global hotkey. Think *JARVIS*, but open‑source and designed with strong security boundaries.

It can:

* Manage packages and processes
* Manipulate files and folders
* Launch applications
* Answer questions using the *best AI model for the task*

All while respecting the **least‑privilege security model**.

---

## 🚀 Key Features

### 🎯 Global Hotkey

* Press **`Ctrl + Alt + L`** (default) to open a lightweight popup
* Type or speak commands naturally

### 🧠 Smart AI Routing

Automatically selects the most suitable AI provider:

| Provider     | Best For                                |
| ------------ | --------------------------------------- |
| **Gemini**   | Research, news, general knowledge       |
| **DeepSeek** | Code generation, debugging, scripting   |
| **ChatGPT**  | Reasoning, comparisons, decision‑making |

### 🖥️ System Control

| Capability         | Examples                                       |
| ------------------ | ---------------------------------------------- |
| Package Management | `install firefox`, `uninstall libreoffice`     |
| File Operations    | `delete ~/old.zip`, `create folder ~/Projects` |
| Process Management | `kill chrome`, `list processes`                |
| App Launching      | `launch vscode`                                |

### 🔐 Secure Sudo Wall

* Privileged actions require **explicit unlock**
* Command:

  ```text
  sudo code: your_password
  ```
* Auto‑locks after **5 minutes** (configurable)

### 🔑 Encrypted Secrets

* API keys encrypted at rest
* Stored in: `/etc/maysie/api_keys.enc`
* System‑generated encryption key
* Keys never appear in logs or linger in memory

### 🐧 Cross‑Distro Support

Auto‑detects your package manager:

| Distro          | Manager |
| --------------- | ------- |
| Debian / Ubuntu | APT     |
| Fedora          | DNF     |
| Arch            | Pacman  |
| openSUSE        | Zypper  |

### 🧩 Minimal UI

* Lightweight GTK popup
* Optional debug web interface

### 📜 Full Logging

* Logs: `/var/log/maysie/maysie.log`
* Automatic log rotation

---

## 🛡️ Security Model

Maysie follows **strict least‑privilege principles**:

* Runs as **your user**, not root
* Uses `systemd` for controlled background execution
* No privileged command without explicit unlock
* Dangerous patterns blocked by default:

  * `rm -rf /`
  * Fork bombs
  * Recursive system wipes
* API keys are:

  * Encrypted
  * Never logged
  * Cleared from memory after use
* Debug Web UI:

  * Localhost only
  * Requires sudo authentication

> ⚠️ **Warning:** Maysie can execute powerful system commands. Only use it on machines you trust.

---

## 📦 Installation

### ✅ Prerequisites

* Linux (Debian, Ubuntu, Fedora, Arch, openSUSE)
* Python **3.9+**
* `sudo` access

### ⚡ One‑Line Install

```bash
git clone https://github.com/Manjil740/maysie.git
cd maysie
sudo chmod +x install.sh
sudo ./install.sh
```

> 🔧 The `chmod +x` step ensures the installer is executable (required on some systems).

### 🔧 What the Installer Does

* Creates required directories:

  * `/opt/maysie`
  * `/etc/maysie`
  * `/var/log/maysie`
* Installs system & Python dependencies
* Sets up `systemd` service (`maysie.service`)
* Starts Maysie automatically

---

## 🔑 First‑Time Setup

1. Press **`Super + Alt + A`**
2. Type:

   ```text
   enter debug mode YOUR_SUDO_PASSWORD
   ```
3. Browser opens at:

   ```text
   http://127.0.0.1:7777
   ```
4. Enter API keys:

   * Google AI Studio (Gemini)
   * OpenAI Platform (ChatGPT)
   * DeepSeek Platform
5. Click **Save API Keys**

🔒 Keys are encrypted immediately. The web UI auto‑closes after **1 hour**.

---

## 🗣️ Usage Examples

| Command                                    |            Action                              |
| ------------------------------------------ | ----------------------------------- |
| `install neofetch`                         | Installs via system package manager |
| `delete file ~/Downloads/temp.txt`         | Deletes a file                      |
| `launch gimp`                              | Starts GIMP                         |
| `kill firefox`                             | Terminates Firefox processes        |
| `respond technical: explain how DNS works` | Detailed technical explanation      |
| `sudo code: mypass`                        | Unlocks sudo for 5 minutes          |
| `enter debug mode mypass`                  | Opens config web UI                 |

---

## 🧰 Configuration

📄 Config file:

```text
/etc/maysie/config.yaml
```

### 🔧 Example Configuration

```yaml
hotkey:
  combination: "Super+Alt+A"

ai:
  default_provider: "auto"
  routing_rules:
    - pattern: "code|debug|script"
      provider: "deepseek"
    - pattern: "research|news|latest"
      provider: "gemini"
```

Configuration can be edited manually or via the debug web UI.

---

## 🛠️ Management

```bash
# Check status
sudo systemctl status maysie

# Restart after config changes
sudo systemctl restart maysie

# View logs
tail -f /var/log/maysie/maysie.log

# Stop / Start
sudo systemctl stop maysie
sudo systemctl start maysie
```

---

## 🗑️ Uninstallation

```bash
cd maysie
sudo chmod +x uninstall.sh
sudo ./uninstall.sh
```

* Optionally backs up configuration before removal

---

## 📁 Project Structure

```text
/opt/maysie/        # Application code
/etc/maysie/        # Config + encrypted API keys
/var/log/maysie/    # Rotating logs
/usr/share/maysie/  # Desktop integration
```

---

## 🤝 Contributing

Pull requests are welcome! Focus areas:

* Additional Linux distro support
* Voice input & speech recognition
* Enhanced security policies
* New AI providers (ChatGpt,Gemini,DeepSeek, etc.)

📌 GitHub Repository:
**[https://github.com/Manjil740/maysie](https://github.com/Manjil740/maysie)**

---

## ⭐ Final Notes

If you like Maysie, consider giving the repo a ⭐ and sharing feedback. Every suggestion helps make it sharper, safer, and smarter.

Happy hacking 🐧
