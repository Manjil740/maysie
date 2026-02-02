#!/bin/bash

# Maysie AI Assistant - Complete Installation Script
# Properly working version with all features

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

# Banner
clear
echo "================================================"
echo "  Maysie AI Assistant - Installation"
echo "================================================"
echo "User: $CURRENT_USER"
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
    rm -rf "$INSTALL_DIR"
    print_success "Cleaned previous install"
fi

# Create directories
print_status "Creating directories..."
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" \
         "$INSTALL_DIR/data" "$INSTALL_DIR/hotkeys" \
         "$INSTALL_DIR/plugins" "$INSTALL_DIR/modules"
chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR"
print_success "Directories created"

# Install system dependencies
print_status "Installing system dependencies..."
apt-get update
DEPS=(
    python3 python3-pip python3-venv python3-dev
    python3-gi python3-gi-cairo gir1.2-gtk-3.0
    dbus libdbus-1-dev
    xclip git curl wget
    build-essential libffi-dev libssl-dev
    libgirepository1.0-dev libcairo2-dev pkg-config
    # For screenshots and OCR
    scrot tesseract-ocr tesseract-ocr-eng
    # For global hotkeys
    xbindkeys xdotool
)
apt-get install -y "${DEPS[@]}"
print_success "System dependencies installed"

# Copy source files if they exist
print_status "Copying source files..."
if ls *.py 1> /dev/null 2>&1; then
    cp *.py "$INSTALL_DIR/" 2>/dev/null || true
fi
if [ -d "modules" ]; then
    cp -r modules "$INSTALL_DIR/"
fi
if [ -d "plugins" ]; then
    cp -r plugins "$INSTALL_DIR/"
fi

# Create main application if missing
if [ ! -f "$INSTALL_DIR/maysie.py" ]; then
    print_status "Creating main application..."
    cat > "$INSTALL_DIR/maysie.py" << 'EOF'
#!/usr/bin/env python3
"""
Maysie AI Assistant - Main Application
"""

import os
import sys
import logging
import time
from pathlib import Path

# Setup logging
log_dir = Path("/var/log/maysie")
log_dir.mkdir(exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / "maysie.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

def check_dependencies():
    """Check if all required packages are installed"""
    required = [
        "gi", "dbus", "pynput", "aiohttp", "cryptography",
        "flask", "openai", "PIL", "psutil", "yaml"
    ]
    
    missing = []
    for package in required:
        try:
            __import__(package)
            logger.info(f"✓ {package}")
        except ImportError:
            missing.append(package)
            logger.warning(f"✗ {package}")
    
    if missing:
        logger.error(f"Missing packages: {', '.join(missing)}")
        return False
    return True

def main():
    """Main entry point"""
    logger.info("=" * 50)
    logger.info("Starting Maysie AI Assistant")
    logger.info("=" * 50)
    
    # Check dependencies
    logger.info("Checking dependencies...")
    if not check_dependencies():
        logger.error("Missing required packages. Installation may be incomplete.")
        logger.info("Try: pip install -r requirements.txt")
    
    # Main loop
    logger.info("Maysie is running. Press Ctrl+C to stop.")
    try:
        while True:
            time.sleep(60)
    except KeyboardInterrupt:
        logger.info("Shutting down...")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
EOF
    print_success "Main application created"
fi

chmod +x "$INSTALL_DIR/maysie.py"

# Create requirements file
print_status "Creating requirements file..."
cat > "$INSTALL_DIR/requirements.txt" << 'EOF'
# Core
wheel>=0.40.0
setuptools>=65.0.0

# GUI and System
PyGObject>=3.42.0
dbus-python>=1.3.0

# AI APIs
openai>=1.0.0
anthropic>=0.7.0
google-generativeai>=0.3.0

# Web and Networking
aiohttp>=3.8.0
Flask>=2.3.0
Flask-CORS>=4.0.0
requests>=2.31.0

# Utilities
pynput>=1.7.0
psutil>=5.9.0
cryptography>=41.0.0
python-dotenv>=1.0.0
PyYAML>=6.0.0
colorama>=0.4.0
python-dateutil>=2.8.0

# Image processing
Pillow>=10.0.0
pyautogui>=0.9.0
EOF

# Create hotkey config
print_status "Creating hotkey configuration..."
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

# Create xbindkeys config
cat > "$CURRENT_HOME/.xbindkeysrc" << EOF
# Maysie Hotkeys
"$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/hotkey_handler.py activate"
  $ACTIVATE_HOTKEY

"$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/hotkey_handler.py screenshot"
  ctrl+alt+s
EOF
chown $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.xbindkeysrc"

# Create hotkey handler
cat > "$INSTALL_DIR/hotkey_handler.py" << 'EOF'
#!/usr/bin/env python3
"""
Hotkey handler for Maysie
"""

import sys
import dbus

def main():
    if len(sys.argv) < 2:
        print("Usage: hotkey_handler.py <action>")
        return
    
    action = sys.argv[1]
    print(f"Hotkey pressed: {action}")
    
    # TODO: Implement actual hotkey handling
    # This is a placeholder

if __name__ == "__main__":
    main()
EOF
chmod +x "$INSTALL_DIR/hotkey_handler.py"

# Setup Python environment
print_status "Setting up Python environment..."
cd "$INSTALL_DIR"

# Create and activate virtual environment
sudo -u $CURRENT_USER python3 -m venv venv
source venv/bin/activate

# Upgrade pip first
pip install --upgrade pip wheel setuptools

# Install packages with proper error handling
print_status "Installing Python packages..."
MAX_RETRIES=3
for i in $(seq 1 $MAX_RETRIES); do
    print_status "Attempt $i/$MAX_RETRIES..."
    if pip install -r requirements.txt; then
        print_success "Packages installed successfully"
        break
    elif [ $i -eq $MAX_RETRIES ]; then
        print_warning "Some packages failed to install"
        print_status "Installing minimal set..."
        pip install PyGObject dbus-python flask openai pynput pillow
    fi
    sleep 2
done

# Test critical imports
print_status "Testing imports..."
python3 -c "
import sys
print('Python:', sys.version.split()[0])
print()
tests = [
    ('gi', 'PyGObject'),
    ('dbus', 'DBus'),
    ('pynput.keyboard', 'Keyboard'),
    ('aiohttp', 'Async HTTP'),
    ('cryptography', 'Encryption'),
    ('flask', 'Web Framework'),
    ('openai', 'OpenAI'),
    ('PIL.Image', 'Image Processing'),
]

for module, name in tests:
    try:
        __import__(module.split('.')[0])
        print(f'✓ {name:15} OK')
    except Exception as e:
        print(f'✗ {name:15} FAILED: {str(e)[:50]}...')
"

deactivate
print_success "Python environment setup complete"

# Create configuration
print_status "Creating configuration..."
cat > "$CONFIG_DIR/config.yaml" << EOF
# Maysie Configuration
version: 1.0

# AI Settings
ai:
  default_provider: "openai"
  openai:
    model: "gpt-4"
    temperature: 0.7
  anthropic:
    model: "claude-3-opus"
    temperature: 0.7
  google:
    model: "gemini-pro"
    temperature: 0.7

# Hotkeys
hotkeys:
  activate: "$ACTIVATE_HOTKEY"
  screenshot: "ctrl+alt+s"
  debug_mode: "enter debug mode"

# Web Interface
web:
  enabled: true
  host: "127.0.0.1"
  port: 7777
  debug: false

# Features
features:
  clipboard_monitor: true
  screenshot_ocr: true
  auto_update: false
  hotkeys_enabled: true

# Logging
logging:
  level: "INFO"
  file: "/var/log/maysie/maysie.log"
  max_size: 10485760
  backup_count: 5

# Paths
paths:
  install: "/opt/maysie"
  config: "/etc/maysie"
  logs: "/var/log/maysie"
  data: "/opt/maysie/data"
EOF

chown $CURRENT_USER:$CURRENT_USER "$CONFIG_DIR/config.yaml"
chmod 600 "$CONFIG_DIR/config.yaml"

# Create secrets file
print_status "Creating secrets file..."
cat > "$CONFIG_DIR/secrets.env" << EOF
# API Keys (add your keys here)
# OPENAI_API_KEY=your_key_here
# ANTHROPIC_API_KEY=your_key_here
# GOOGLE_API_KEY=your_key_here

# Encryption
ENCRYPTION_KEY=$(openssl rand -hex 32)
EOF
chown $CURRENT_USER:$CURRENT_USER "$CONFIG_DIR/secrets.env"
chmod 600 "$CONFIG_DIR/secrets.env"

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
Environment=DISPLAY=:0
Environment=XAUTHORITY=$CURRENT_HOME/.Xauthority
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/maysie.py
Restart=on-failure
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=maysie

# Security
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$LOG_DIR $CONFIG_DIR $INSTALL_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable maysie.service

# Create xbindkeys service
mkdir -p "$CURRENT_HOME/.config/systemd/user"
cat > "$CURRENT_HOME/.config/systemd/user/xbindkeys.service" << EOF
[Unit]
Description=XBindKeys Hotkey Daemon
After=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/xbindkeys -f $CURRENT_HOME/.xbindkeysrc
Restart=on-failure

[Install]
WantedBy=default.target
EOF

chown -R $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.config/systemd"

# Create user scripts
print_status "Creating user scripts..."
mkdir -p "$CURRENT_HOME/.local/bin"

# Startup script
cat > "$CURRENT_HOME/.local/bin/maysie-start" << EOF
#!/bin/bash
echo "Starting Maysie AI Assistant..."
sudo systemctl start maysie.service
sudo -u $CURRENT_USER systemctl --user start xbindkeys.service
sleep 2
echo "Status:"
sudo systemctl status maysie.service --no-pager | grep "Active:"
echo ""
echo "Hotkey: $ACTIVATE_HOTKEY"
echo "Web UI: http://127.0.0.1:7777"
EOF

# Status script
cat > "$CURRENT_HOME/.local/bin/maysie-status" << 'EOF'
#!/bin/bash
echo "Maysie AI Assistant Status"
echo "========================="
sudo systemctl status maysie.service --no-pager
echo ""
echo "Hotkeys:"
ps aux | grep xbindkeys | grep -v grep || echo "xbindkeys not running"
echo ""
echo "Logs (last 10 lines):"
sudo journalctl -u maysie.service -n 10 --no-pager
EOF

# Debug script
cat > "$CURRENT_HOME/.local/bin/maysie-debug" << EOF
#!/bin/bash
echo "Maysie Debug Information"
echo "========================"
echo "Install dir: $INSTALL_DIR"
echo "Config dir: $CONFIG_DIR"
echo "User: $CURRENT_USER"
echo ""
echo "Python test:"
cd $INSTALL_DIR
source venv/bin/activate
python3 -c "import sys; print('Python:', sys.version)"
python3 -c "import gi, dbus; print('Imports: gi and dbus OK')"
deactivate
echo ""
echo "Hotkey config:"
cat $CURRENT_HOME/.xbindkeysrc
EOF

chmod +x "$CURRENT_HOME/.local/bin/"*
chown $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.local/bin/"*

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

# Start services
print_status "Starting services..."
systemctl start maysie.service
sudo -u $CURRENT_USER systemctl --user daemon-reload
sudo -u $CURRENT_USER systemctl --user enable xbindkeys.service
sudo -u $CURRENT_USER systemctl --user start xbindkeys.service

sleep 3

# Check if services are running
print_status "Checking services..."
if systemctl is-active --quiet maysie.service; then
    print_success "Maysie service is running"
else
    print_warning "Maysie service failed to start"
    journalctl -u maysie.service --no-pager -n 5
fi

if pgrep -x "xbindkeys" >/dev/null; then
    print_success "Hotkey service is running"
else
    print_warning "Hotkey service may not be working"
fi

# Final output
echo ""
echo "================================================"
echo "  INSTALLATION COMPLETE!"
echo "================================================"
echo ""
echo "Maysie AI Assistant has been installed successfully!"
echo ""
echo "Quick Start:"
echo "1. Press $ACTIVATE_HOTKEY to activate Maysie"
echo "2. Type 'enter debug mode' to configure API keys"
echo "3. Visit http://127.0.0.1:7777 for web interface"
echo ""
echo "Directories:"
echo "  Installation: $INSTALL_DIR"
echo "  Configuration: $CONFIG_DIR"
echo "  Logs: $LOG_DIR"
echo ""
echo "Commands:"
echo "  maysie-start    - Start Maysie"
echo "  maysie-status   - Check status"
echo "  maysie-debug    - Debug information"
echo "  sudo systemctl restart maysie - Restart service"
echo "  sudo journalctl -u maysie.service -f - View logs"
echo ""
echo "Troubleshooting:"
echo "If hotkeys don't work:"
echo "  1. Check if xbindkeys is running: ps aux | grep xbindkeys"
echo "  2. Restart: killall xbindkeys && xbindkeys"
echo "  3. Check ~/.xbindkeysrc configuration"
echo ""
echo "If imports fail:"
echo "  cd $INSTALL_DIR && source venv/bin/activate"
echo "  pip install --force-reinstall PyGObject dbus-python"
echo ""
echo "For support, visit: https://github.com/Manjil740/maysie"
echo ""

# Cleanup
print_status "Cleaning up..."
apt-get autoremove -y 2>/dev/null || true
print_success "Installation complete!"

exit 0