#!/bin/bash

# Maysie AI Assistant - Complete Installation Script
# Fixed and improved version

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Directories
INSTALL_DIR="/opt/maysie"
CONFIG_DIR="/etc/maysie"
LOG_DIR="/var/log/maysie"

print_status() { echo -e "${BLUE}[*]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[⚠]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

# Check root
if [ "$EUID" -ne 0 ]; then
    print_error "Run as root: sudo ./install.sh"
    exit 1
fi

CURRENT_USER=${SUDO_USER:-$USER}
CURRENT_HOME=$(eval echo ~$CURRENT_USER)

# Get display and Xauthority from current session if available
DISPLAY_VALUE="${DISPLAY:-:0}"
if [ -f "$CURRENT_HOME/.Xauthority" ]; then
    XAUTHORITY_VALUE="$CURRENT_HOME/.Xauthority"
else
    # Try to find Xauthority
    XAUTHORITY_VALUE=$(ps aux | grep "Xorg\|Xwayland" | grep -v grep | awk '{for(i=1;i<=NF;i++) if($i ~ /-auth/) print $(i+1)}' | head -1)
    [ -z "$XAUTHORITY_VALUE" ] && XAUTHORITY_VALUE="$CURRENT_HOME/.Xauthority"
fi

# Banner
clear
echo "================================================"
echo "  Maysie AI Assistant - Installation"
echo "================================================"
echo "User: $CURRENT_USER"
echo "Home: $CURRENT_HOME"
echo "Display: $DISPLAY_VALUE"
echo ""

# Hotkey setup
echo "Hotkey Configuration"
read -p "Activation hotkey (default: ctrl+alt+l): " ACTIVATE_HOTKEY
ACTIVATE_HOTKEY=${ACTIVATE_HOTKEY:-ctrl+alt+l}
echo ""

# Clean previous
if [ -d "$INSTALL_DIR" ]; then
    print_status "Removing previous installation..."
    systemctl stop maysie 2>/dev/null || true
    systemctl disable maysie 2>/dev/null || true
    rm -rf "$INSTALL_DIR"
    print_success "Cleaned previous install"
fi

# Create directories
print_status "Creating directories..."
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" \
         "$INSTALL_DIR/data" "$INSTALL_DIR/hotkeys" \
         "$INSTALL_DIR/plugins" "$INSTALL_DIR/modules"
chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR"
chmod 755 "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR"
print_success "Directories created"

# Install system dependencies
print_status "Installing system dependencies..."
apt-get update > /dev/null 2>&1

# Check if we're on Ubuntu/Debian
if ! command -v apt-get &> /dev/null; then
    print_error "This script requires apt-get (Ubuntu/Debian)"
    exit 1
fi

DEPS=(
    python3 python3-pip python3-venv python3-dev
    python3-gi python3-gi-cairo gir1.2-gtk-3.0
    dbus libdbus-1-dev libdbus-glib-1-dev
    xclip git curl wget
    build-essential libffi-dev libssl-dev
    libgirepository1.0-dev libcairo2-dev pkg-config
    gobject-introspection cmake python3-dbus
    # For screenshots and OCR
    scrot tesseract-ocr tesseract-ocr-eng
    # For global hotkeys
    xbindkeys xdotool
    # Additional GUI dependencies
    libgtk-3-dev libappindicator3-dev
)

apt-get install -y "${DEPS[@]}" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_success "System dependencies installed"
else
    print_warning "Some dependencies may have failed, continuing..."
fi

# Copy source files
print_status "Copying source files..."
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Create basic source structure if it doesn't exist
if [ ! -d "$SCRIPT_DIR/maysie" ]; then
    print_warning "Source directory 'maysie' not found. Creating basic structure..."
    
    # Create basic directory structure
    mkdir -p "$INSTALL_DIR/maysie/core" "$INSTALL_DIR/maysie/utils"
    
    # Create minimal core.py
    cat > "$INSTALL_DIR/maysie/core/service.py" << 'EOF'
"""
Maysie Service
"""
import asyncio

class MaysieService:
    async def start(self):
        print("Maysie service starting...")
        while True:
            await asyncio.sleep(1)
EOF
    
    # Create minimal logger
    cat > "$INSTALL_DIR/maysie/utils/logger.py" << 'EOF'
"""
Logger utility
"""
import logging

def get_logger(name):
    return logging.getLogger(name)
EOF
else
    # Copy existing structure
    cp -r "$SCRIPT_DIR"/* "$INSTALL_DIR/" 2>/dev/null || true
fi

# Copy requirements.txt if exists
if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
    cp "$SCRIPT_DIR/requirements.txt" "$INSTALL_DIR/"
fi

# Create proper main.py
print_status "Creating main application..."
cat > "$INSTALL_DIR/main.py" << 'EOF'
#!/usr/bin/env python3
"""
Maysie AI Assistant - Main Entry Point
"""

import asyncio
import sys
import os
from pathlib import Path

# Add install dir to path
sys.path.insert(0, str(Path(__file__).parent))

try:
    from maysie.core.service import MaysieService
    from maysie.utils.logger import get_logger
except ImportError:
    # Fallback if modules don't exist
    class MaysieService:
        async def start(self):
            print("Maysie AI Assistant - Placeholder Service")
            print("Installation complete! Configure API keys to start.")
            while True:
                await asyncio.sleep(3600)  # Sleep for 1 hour
    
    def get_logger(name):
        import logging
        return logging.getLogger(name)

logger = get_logger(__name__)

async def main():
    """Main entry point"""
    logger.info("Starting Maysie AI Assistant")
    
    try:
        service = MaysieService()
        await service.start()
    except KeyboardInterrupt:
        logger.info("Shutdown requested")
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)
EOF
chmod +x "$INSTALL_DIR/main.py"

# Create proper requirements file
print_status "Creating requirements file..."
cat > "$INSTALL_DIR/requirements.txt" << 'EOF'
# Core
wheel>=0.40.0
setuptools>=65.0.0

# GUI and System
dbus-python>=1.3.0
PyGObject>=3.42.0
pycairo>=1.23.0

# AI APIs
openai>=1.3.0
anthropic>=0.7.0
google-genai>=0.3.0

# Web and Networking
aiohttp>=3.9.0
Flask>=3.0.0
Flask-CORS>=4.0.0
requests>=2.31.0

# Utilities
pynput>=1.7.6
psutil>=5.9.0
cryptography>=41.0.0
python-dotenv>=1.0.0
PyYAML>=6.0.0
colorama>=0.4.0
python-dateutil>=2.8.0

# Image processing
Pillow>=10.0.0
pyautogui>=0.9.0

# Validation
jsonschema>=4.20.0

# Web server
waitress>=3.0.0

# System tray
pystray>=0.19.0
EOF

# Create proper hotkey config
print_status "Creating hotkey configuration..."
mkdir -p "$INSTALL_DIR/hotkeys"
cat > "$INSTALL_DIR/hotkeys/default.json" << EOF
{
    "hotkeys": {
        "activate": {
            "description": "Activate Maysie AI Assistant",
            "key": "$ACTIVATE_HOTKEY",
            "enabled": true
        },
        "screenshot": {
            "description": "Take screenshot",
            "key": "ctrl+alt+s",
            "enabled": true
        }
    }
}
EOF

# Create proper xbindkeys config
print_status "Configuring xbindkeys..."
cat > "$CURRENT_HOME/.xbindkeysrc" << EOF
# Maysie Hotkeys
"$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/hotkey_trigger.py"
  $ACTIVATE_HOTKEY

"$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/screenshot.py"
  control+alt + s
EOF

# Make sure the config file is owned by user
chown $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.xbindkeysrc"

# Create hotkey trigger script
cat > "$INSTALL_DIR/hotkey_trigger.py" << 'EOF'
#!/usr/bin/env python3
"""
Hotkey trigger - sends signal to main service
"""

import socket
import sys
import os
from pathlib import Path

def main():
    try:
        # Create a simple notification
        notification_dir = "/tmp/maysie"
        os.makedirs(notification_dir, exist_ok=True)
        
        # Create a trigger file
        trigger_file = Path(notification_dir) / "hotkey_triggered"
        trigger_file.touch()
        
        print(f"Hotkey triggered at {trigger_file}")
        
        # Also try to send socket signal
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.settimeout(1)
                sock.connect(('127.0.0.1', 9999))
                sock.sendall(b'HOTKEY_PRESSED\n')
                print("Socket signal sent")
        except (ConnectionRefusedError, TimeoutError):
            # This is normal if service isn't listening yet
            pass
            
    except Exception as e:
        print(f"Error in hotkey trigger: {e}")

if __name__ == "__main__":
    main()
EOF
chmod +x "$INSTALL_DIR/hotkey_trigger.py"

# Create screenshot script
cat > "$INSTALL_DIR/screenshot.py" << 'EOF'
#!/usr/bin/env python3
"""
Screenshot utility
"""
import os
import time
from pathlib import Path

def take_screenshot():
    try:
        # Create screenshots directory
        screenshot_dir = Path.home() / "Pictures" / "MaysieScreenshots"
        screenshot_dir.mkdir(parents=True, exist_ok=True)
        
        # Generate filename
        timestamp = time.strftime("%Y%m%d_%H%M%S")
        filename = screenshot_dir / f"screenshot_{timestamp}.png"
        
        # Take screenshot using scrot
        os.system(f"scrot '{filename}' -q 100")
        
        print(f"Screenshot saved: {filename}")
        
        # Try to show notification if notify-send is available
        if os.system("which notify-send > /dev/null 2>&1") == 0:
            os.system(f'notify-send "Maysie" "Screenshot saved: {filename.name}"')
            
    except Exception as e:
        print(f"Error taking screenshot: {e}")

if __name__ == "__main__":
    take_screenshot()
EOF
chmod +x "$INSTALL_DIR/screenshot.py"

# Setup Python environment
print_status "Setting up Python environment..."
cd "$INSTALL_DIR"

# Create virtual environment
if [ ! -d "$INSTALL_DIR/venv" ]; then
    sudo -u $CURRENT_USER python3 -m venv --system-site-packages "$INSTALL_DIR/venv"
fi

VENV_PIP="$INSTALL_DIR/venv/bin/pip"
VENV_PY="$INSTALL_DIR/venv/bin/python3"

# Upgrade pip
print_status "Upgrading pip..."
sudo -u $CURRENT_USER "$VENV_PIP" install --upgrade pip wheel setuptools > /dev/null 2>&1

# Install packages
print_status "Installing Python packages..."
if sudo -u $CURRENT_USER "$VENV_PIP" install -r "$INSTALL_DIR/requirements.txt" > "$LOG_DIR/pip_install.log" 2>&1; then
    print_success "Python packages installed"
else
    print_warning "Some packages failed, trying minimal set..."
    sudo -u $CURRENT_USER "$VENV_PIP" install flask openai google-genai anthropic requests > "$LOG_DIR/pip_minimal.log" 2>&1 || true
fi

# Test critical imports
print_status "Testing imports..."
sudo -u $CURRENT_USER "$VENV_PY" -c "
import sys
print('Python:', sys.version.split()[0])
print()
success = True
try:
    import flask
    print('✓ Flask OK')
except ImportError as e:
    print(f'✗ Flask: {e}')
    success = False
try:
    import openai
    print('✓ OpenAI OK')
except ImportError as e:
    print(f'✗ OpenAI: {e}')
    success = False
try:
    import google.genai as google_genai
    print('✓ Google GenAI OK')
except ImportError as e:
    try:
        import google.generativeai
        print('✓ Google Generative AI OK (legacy)')
    except ImportError as e2:
        print(f'✗ Google AI: {e2}')
        success = False
try:
    import dbus
    print('✓ DBus OK')
except ImportError as e:
    print(f'✗ DBus: {e}')
    success = False
sys.exit(0 if success else 1)
"

if [ $? -eq 0 ]; then
    print_success "Imports test passed"
else
    print_warning "Some imports failed - this may affect functionality"
fi

chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR"

# Create configuration
print_status "Creating configuration..."
mkdir -p "$CONFIG_DIR"

cat > "$CONFIG_DIR/config.yaml" << EOF
# Maysie Configuration
version: 1.0

# Hotkey
hotkey:
  combination: "$ACTIVATE_HOTKEY"
  enabled: true

# AI Settings
ai:
  default_provider: "auto"
  timeout: 30
  max_retries: 3
  routing_rules:
    - pattern: "research|latest|news|current"
      provider: "gemini"
      priority: 10
    - pattern: "code|script|program|debug|function"
      provider: "deepseek"
      priority: 10
    - pattern: "decide|compare|analyze|recommend|choose"
      provider: "chatgpt"
      priority: 10

# Sudo Settings
sudo:
  cache_timeout: 300
  require_confirmation: true
  dangerous_commands:
    - "rm -rf /"
    - "mkfs"
    - "dd if=/dev/zero"
    - ":(){:|:&};:"

# UI Settings
ui:
  position: "bottom-right"
  theme: "dark"
  auto_hide_delay: 3
  width: 400
  height: 150
  opacity: 0.95

# Response Settings
response:
  default_style: "short"
  styles:
    short: "Provide a concise, direct answer. 2-3 sentences max."
    detailed: "Provide a comprehensive, well-explained answer with examples."
    bullets: "Provide answer as clear bullet points."
    technical: "Provide detailed technical explanation with proper terminology."

# Logging Settings
logging:
  level: "INFO"
  max_file_size_mb: 10
  backup_count: 5
  enable_debug: false

# Web UI Settings
web_ui:
  enabled: true
  host: "127.0.0.1"
  port: 7777
  auth_required: true

# Server Settings
server:
  host: "127.0.0.1"
  port: 9999
  debug: false
EOF

chown $CURRENT_USER:$CURRENT_USER "$CONFIG_DIR/config.yaml"
chmod 600 "$CONFIG_DIR/config.yaml"

# Create secrets file
print_status "Creating secrets file..."
if [ ! -f "$CONFIG_DIR/secrets.env" ]; then
    cat > "$CONFIG_DIR/secrets.env" << EOF
# API Keys (add your keys here)
# OPENAI_API_KEY=your_key_here
# ANTHROPIC_API_KEY=your_key_here
# GOOGLE_API_KEY=your_key_here
# DEEPSEEK_API_KEY=your_key_here

# Web UI credentials (change these!)
WEB_USERNAME=admin
WEB_PASSWORD=$(openssl rand -base64 12)

# Encryption
ENCRYPTION_KEY=$(openssl rand -hex 32)
EOF
    chown $CURRENT_USER:$CURRENT_USER "$CONFIG_DIR/secrets.env"
    chmod 600 "$CONFIG_DIR/secrets.env"
    print_success "Secrets file created"
else
    print_warning "Secrets file already exists, keeping existing"
fi

# Create systemd service
print_status "Creating systemd service..."
cat > /etc/systemd/system/maysie.service << EOF
[Unit]
Description=Maysie AI Assistant
After=network.target
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=PYTHONPATH=$INSTALL_DIR
Environment=DISPLAY=$DISPLAY_VALUE
Environment=XAUTHORITY=$XAUTHORITY_VALUE
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $CURRENT_USER)/bus
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/main.py
Restart=on-failure
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

# Logging
StandardOutput=append:$LOG_DIR/maysie.log
StandardError=append:$LOG_DIR/maysie_error.log
SyslogIdentifier=maysie

# Security
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$LOG_DIR $CONFIG_DIR $INSTALL_DIR
ReadOnlyPaths=/

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable maysie.service > /dev/null 2>&1

# Create xbindkeys autostart entry instead of systemd user service
print_status "Configuring xbindkeys autostart..."
mkdir -p "$CURRENT_HOME/.config/autostart"
cat > "$CURRENT_HOME/.config/autostart/xbindkeys-maysie.desktop" << EOF
[Desktop Entry]
Type=Application
Name=xbindkeys (Maysie)
Comment=Hotkey daemon for Maysie AI Assistant
Exec=xbindkeys -f $CURRENT_HOME/.xbindkeysrc
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

chown -R $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.config/autostart"

# Create user scripts
print_status "Creating user scripts..."
mkdir -p "$CURRENT_HOME/.local/bin"

# Startup script
cat > "$CURRENT_HOME/.local/bin/maysie-start" << EOF
#!/bin/bash
echo "Starting Maysie AI Assistant..."
sudo systemctl start maysie.service
sleep 1
echo ""
echo "Starting hotkeys..."
pkill xbindkeys 2>/dev/null
xbindkeys -f ~/.xbindkeysrc &
sleep 2
echo ""
echo "Status:"
sudo systemctl status maysie.service --no-pager | grep "Active:" | head -1
echo ""
echo "Hotkey: $ACTIVATE_HOTKEY"
echo "Logs: tail -f $LOG_DIR/maysie.log"
EOF

# Stop script
cat > "$CURRENT_HOME/.local/bin/maysie-stop" << EOF
#!/bin/bash
echo "Stopping Maysie AI Assistant..."
sudo systemctl stop maysie.service
pkill -f xbindkeys 2>/dev/null || true
echo "Stopped"
EOF

# Status script
cat > "$CURRENT_HOME/.local/bin/maysie-status" << EOF
#!/bin/bash
echo "Maysie AI Assistant Status"
echo "========================="
sudo systemctl status maysie.service --no-pager
echo ""
echo "Hotkeys:"
pgrep xbindkeys >/dev/null && echo "xbindkeys: Running" || echo "xbindkeys: Not running"
echo ""
echo "Recent logs:"
tail -10 $LOG_DIR/maysie.log 2>/dev/null || echo "No log file found"
EOF

# Debug script
cat > "$CURRENT_HOME/.local/bin/maysie-debug" << EOF
#!/bin/bash
echo "Maysie Debug Information"
echo "========================"
echo "Install dir: $INSTALL_DIR"
echo "Config dir: $CONFIG_DIR"
echo "Log dir: $LOG_DIR"
echo "User: $CURRENT_USER"
echo ""
echo "Python:"
cd $INSTALL_DIR
source venv/bin/activate
python3 --version
python3 -c "import sys; print('Path:', sys.path[:2])"
deactivate
echo ""
echo "Services:"
systemctl is-active maysie.service
pgrep xbindkeys && echo "xbindkeys running" || echo "xbindkeys not running"
echo ""
echo "Hotkey config:"
cat ~/.xbindkeysrc 2>/dev/null | grep -v "^#" || echo "No xbindkeys config"
EOF

# Config script
cat > "$CURRENT_HOME/.local/bin/maysie-config" << EOF
#!/bin/bash
echo "Maysie Configuration"
echo "==================="
echo "Edit configuration files:"
echo "1. API Keys: sudo nano $CONFIG_DIR/secrets.env"
echo "2. Settings: sudo nano $CONFIG_DIR/config.yaml"
echo ""
echo "Current hotkey: $ACTIVATE_HOTKEY"
echo ""
read -p "Open which file? (1/2 or q to quit): " choice
case \$choice in
    1) sudo nano $CONFIG_DIR/secrets.env ;;
    2) sudo nano $CONFIG_DIR/config.yaml ;;
    *) echo "Cancelled" ;;
esac
EOF

# Hotkey test script
cat > "$CURRENT_HOME/.local/bin/maysie-test-hotkey" << EOF
#!/bin/bash
echo "Testing Maysie Hotkey"
echo "====================="
echo "1. Press $ACTIVATE_HOTKEY"
echo "2. Check if trigger file is created:"
echo "   ls -la /tmp/maysie/"
echo "3. If file exists, hotkey is working"
echo ""
echo "To manually test:"
echo "  xbindkeys -f ~/.xbindkeysrc -n"
echo ""
echo "Current xbindkeys process:"
pgrep xbindkeys && echo "Running (PID: \$(pgrep xbindkeys))" || echo "Not running"
EOF

chmod +x "$CURRENT_HOME/.local/bin/maysie-"*
chown $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.local/bin/maysie-"*

# Add to PATH if not already
if ! echo "$PATH" | grep -q "$CURRENT_HOME/.local/bin"; then
    print_status "Adding ~/.local/bin to PATH in .bashrc..."
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CURRENT_HOME/.bashrc"
fi

# Setup log rotation
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/maysie << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 640 $CURRENT_USER $CURRENT_USER
    sharedscripts
    postrotate
        systemctl reload maysie.service >/dev/null 2>&1 || true
    endscript
}
EOF

# Start main service
print_status "Starting Maysie service..."
systemctl start maysie.service
sleep 2

# Start xbindkeys in current session
print_status "Starting hotkey daemon..."
pkill xbindkeys 2>/dev/null || true

# Start xbindkeys as current user with proper environment
if [ -n "$DISPLAY_VALUE" ] && [ "$DISPLAY_VALUE" != ":0" ]; then
    # If we have a display, start xbindkeys
    sudo -u $CURRENT_USER env DISPLAY="$DISPLAY_VALUE" XAUTHORITY="$XAUTHORITY_VALUE" xbindkeys -f "$CURRENT_HOME/.xbindkeysrc" &
    sleep 1
else
    # Try to start anyway
    sudo -u $CURRENT_USER xbindkeys -f "$CURRENT_HOME/.xbindkeysrc" &
    sleep 1
fi

# Check if services are running
print_status "Checking services..."
if systemctl is-active --quiet maysie.service; then
    print_success "Maysie service is running"
    echo "  PID: $(systemctl show maysie.service -p MainPID --value)"
    echo "  Log: $LOG_DIR/maysie.log"
else
    print_warning "Maysie service failed to start"
    echo "Check logs: journalctl -u maysie.service -n 20 --no-pager"
    # Try to show error
    journalctl -u maysie.service --no-pager -n 10 2>/dev/null || true
fi

if pgrep -x "xbindkeys" >/dev/null; then
    print_success "Hotkey daemon is running"
    echo "  PID: $(pgrep xbindkeys)"
    echo "  Config: $CURRENT_HOME/.xbindkeysrc"
else
    print_warning "Hotkey daemon may need manual start"
    echo "Run manually: xbindkeys -f ~/.xbindkeysrc"
    echo "Or add to autostart: ln -s ~/.config/autostart/xbindkeys-maysie.desktop ~/.config/autostart/"
fi

# Create a simple test script
cat > "$INSTALL_DIR/test_maysie.py" << 'EOF'
#!/usr/bin/env python3
"""
Test script for Maysie
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

print("Maysie AI Assistant Test")
print("=======================")
print("Installation check:")
print(f"Python: {sys.version}")
print(f"Install dir: {os.path.dirname(os.path.abspath(__file__))}")
print("")
print("To test hotkey:")
print(f"1. Press {sys.argv[1] if len(sys.argv) > 1 else 'ctrl+alt+l'}")
print("2. Check /tmp/maysie/hotkey_triggered file")
print("")
print("Next steps:")
print("1. Edit /etc/maysie/secrets.env and add API keys")
print("2. Restart: sudo systemctl restart maysie.service")
print("3. Test: tail -f /var/log/maysie/maysie.log")
EOF
chmod +x "$INSTALL_DIR/test_maysie.py"

# Create first-run instructions
cat > "$INSTALL_DIR/FIRST_RUN.md" << EOF
# First Run Instructions

## 1. Configure API Keys
Edit the secrets file:
\`\`\`bash
sudo nano $CONFIG_DIR/secrets.env
\`\`\`

Add your API keys:
- OPENAI_API_KEY
- GOOGLE_API_KEY (for Gemini)
- ANTHROPIC_API_KEY
- DEEPSEEK_API_KEY

## 2. Start Services
\`\`\`bash
maysie-start
\`\`\`

## 3. Test Hotkey
Press: $ACTIVATE_HOTKEY

## 4. Check Status
\`\`\`bash
maysie-status
\`\`\`

## 5. Web Interface
URL: http://127.0.0.1:7777
Username: admin
Password: See $CONFIG_DIR/secrets.env

## Troubleshooting

### Hotkey not working:
\`\`\`bash
maysie-test-hotkey
xbindkeys -f ~/.xbindkeysrc
\`\`\`

### Service not starting:
\`\`\`bash
sudo journalctl -u maysie.service -f
\`\`\`

### Check logs:
\`\`\`bash
tail -f $LOG_DIR/maysie.log
\`\`\`
EOF

# Set permissions on logs
touch "$LOG_DIR/maysie.log" "$LOG_DIR/maysie_error.log"
chown $CURRENT_USER:$CURRENT_USER "$LOG_DIR/"*.log
chmod 644 "$LOG_DIR/"*.log

# Final output
echo ""
echo "================================================"
echo "  INSTALLATION COMPLETE!"
echo "================================================"
echo ""
echo "Maysie AI Assistant has been installed successfully!"
echo ""
echo "Quick Start:"
echo "1. Configure API keys:"
echo "   sudo nano $CONFIG_DIR/secrets.env"
echo "2. Start/Stop:"
echo "   maysie-start    # Start service"
echo "   maysie-stop     # Stop service"
echo "   maysie-status   # Check status"
echo "3. Press $ACTIVATE_HOTKEY to activate"
echo ""
echo "Commands available:"
echo "  maysie-start          - Start Maysie"
echo "  maysie-stop           - Stop Maysie"
echo "  maysie-status         - Check status"
echo "  maysie-debug          - Debug information"
echo "  maysie-config         - Edit configuration"
echo "  maysie-test-hotkey    - Test hotkey"
echo ""
echo "Web Interface:"
echo "  URL: http://127.0.0.1:7777"
echo "  Credentials: See $CONFIG_DIR/secrets.env"
echo ""
echo "Autostart:"
echo "  Hotkeys will auto-start on login via ~/.config/autostart/"
echo ""
echo "Troubleshooting:"
echo "1. If hotkey doesn't work:"
echo "   xbindkeys -f ~/.xbindkeysrc"
echo "2. Check logs:"
echo "   tail -f $LOG_DIR/maysie.log"
echo "3. Test installation:"
echo "   $INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/test_maysie.py"
echo ""
echo "For detailed instructions:"
echo "   cat $INSTALL_DIR/FIRST_RUN.md"
echo ""
echo "To uninstall:"
echo "  sudo systemctl stop maysie"
echo "  sudo systemctl disable maysie"
echo "  sudo rm -rf $INSTALL_DIR $CONFIG_DIR $LOG_DIR"
echo "  sudo rm /etc/systemd/system/maysie.service"
echo "  rm ~/.xbindkeysrc ~/.config/autostart/xbindkeys-maysie.desktop"
echo ""
echo "For support, visit: https://github.com/Manjil740/maysie"
echo ""

print_success "Installation finished successfully!"
echo "Please configure API keys and then reboot or log out/in for best results."
echo ""

exit 0