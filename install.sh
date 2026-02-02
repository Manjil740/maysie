#!/bin/bash

# Maysie AI Assistant - Installation Script
# Updated with Ctrl+Alt+L as default hotkey

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Installation directories
INSTALL_DIR="/opt/maysie"
CONFIG_DIR="/etc/maysie"
LOG_DIR="/var/log/maysie"
TEMP_DIR="/tmp/maysie"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[*]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    print_error "Please run as root or with sudo"
    exit 1
fi

# Get current user (for non-root installations)
CURRENT_USER=${SUDO_USER:-$USER}
CURRENT_HOME=$(eval echo ~$CURRENT_USER)

# Banner
clear
echo "================================================"
echo "  Maysie AI Assistant - Installation"
echo "================================================"
echo ""
echo "Installing for user: $CURRENT_USER"
echo ""

# Ask for hotkey preferences
echo "Hotkey Configuration"
echo "===================="
echo "Default activation hotkey: Ctrl + Alt + L"
echo ""
echo "You can customize hotkeys now or edit them later in the configuration file."
echo ""
read -p "Press Enter to use defaults, or 'c' to customize: " -n 1 -r HOTKEY_CHOICE
echo ""

if [[ $HOTKEY_CHOICE =~ ^[Cc]$ ]]; then
    echo "Hotkey Customization"
    echo "-------------------"
    echo "Available modifier keys: ctrl, alt, shift, super (windows/command key)"
    echo ""
    echo "Example formats:"
    echo "  'ctrl+alt+l' for Ctrl+Alt+L"
    echo "  'super+a' for Super+A"
    echo "  'ctrl+shift+space' for Ctrl+Shift+Space"
    echo ""
    
    read -p "Activation hotkey (default: ctrl+alt+l): " ACTIVATE_HOTKEY
    ACTIVATE_HOTKEY=${ACTIVATE_HOTKEY:-ctrl+alt+l}
    
    read -p "Screenshot hotkey (default: ctrl+alt+s): " SCREENSHOT_HOTKEY
    SCREENSHOT_HOTKEY=${SCREENSHOT_HOTKEY:-ctrl+alt+s}
    
    read -p "Quit hotkey (default: ctrl+alt+q): " QUIT_HOTKEY
    QUIT_HOTKEY=${QUIT_HOTKEY:-ctrl+alt+q}
    
    read -p "Debug mode command (default: 'enter debug mode'): " DEBUG_COMMAND
    DEBUG_COMMAND=${DEBUG_COMMAND:-enter debug mode}
else
    ACTIVATE_HOTKEY="ctrl+alt+l"
    SCREENSHOT_HOTKEY="ctrl+alt+s"
    QUIT_HOTKEY="ctrl+alt+q"
    DEBUG_COMMAND="enter debug mode"
fi

# Create the temporary directory for systemd early
print_status "Creating temporary directory for systemd..."
mkdir -p "$TEMP_DIR"
chmod 1777 "$TEMP_DIR"
print_success "Temporary directory created"

# Check if we should clean previous installation
if [ -d "$INSTALL_DIR" ]; then
    print_warning "Previous installation found at $INSTALL_DIR"
    read -p "Do you want to remove it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Removing previous installation..."
        systemctl stop maysie 2>/dev/null || true
        rm -rf "$INSTALL_DIR"
        print_success "Previous installation removed"
    fi
fi

# Detect OS
print_status "Detecting OS..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VERSION=$VERSION_ID
    print_success "Detected: $OS $VERSION"
else
    print_error "Could not detect OS"
    exit 1
fi

# Check Python
print_status "Verifying Python version..."
if command -v python3 >/dev/null 2>&1; then
    PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
    print_success "Python $PYTHON_VERSION detected"
else
    print_error "Python 3 not found"
    exit 1
fi

# Install system dependencies
print_status "Installing system dependencies..."
print_status "Updating package list..."
apt-get update -qq

# Core dependencies
print_status "Installing core dependencies..."
DEPS=(
    python3 python3-pip python3-venv python3-dev
    python3-gi python3-gi-cairo gir1.2-gtk-3.0 gir1.2-glib-2.0
    python3-cairo python3-cairo-dev libcairo2-dev
    libgirepository1.0-dev libgirepository-1.0-1
    gobject-introspection pkg-config build-essential
    curl wget git xclip
    dbus libdbus-1-dev libdbus-glib-1-dev
    sudo systemd ca-certificates
    libffi-dev libssl-dev
    meson ninja-build
    # Additional dependencies
    gcc g++ make cmake
    libatk1.0-dev libpango1.0-dev libgdk-pixbuf-2.0-dev
    libjpeg-dev libtiff-dev libwebp-dev
    libreadline-dev libsqlite3-dev
    libbz2-dev liblzma-dev
    libncursesw5-dev libxml2-dev libxmlsec1-dev
    libffi-dev libssl-dev zlib1g-dev
    libgdbm-dev libnss3-dev
    libxext-dev libxrender-dev libxft-dev
    libglib2.0-dev libmount-dev libselinux1-dev
    # For hotkey detection and input
    xdotool xbindkeys
)

apt-get install -y "${DEPS[@]}"
print_success "System dependencies installed"

# Create directories
print_status "Creating directories..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$CONFIG_DIR"
mkdir -p "$LOG_DIR"
mkdir -p "$INSTALL_DIR/data"
mkdir -p "$INSTALL_DIR/cache"
mkdir -p "$INSTALL_DIR/plugins"
mkdir -p "$INSTALL_DIR/hotkeys"
chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR"
chown -R $CURRENT_USER:$CURRENT_USER "$CONFIG_DIR"
chown -R $CURRENT_USER:$CURRENT_USER "$LOG_DIR"
chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR/data"
chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR/cache"
chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR/plugins"
chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR/hotkeys"
print_success "Directories created"

# Copy application files
print_status "Copying application files..."
print_status "Cleaning up previous installation..."
rm -rf "$INSTALL_DIR"/* 2>/dev/null || true

print_status "Copying source files..."
# Copy all Python files
find . -maxdepth 1 -name "*.py" -exec cp {} "$INSTALL_DIR/" \; 2>/dev/null || true

# Copy configuration files
find . -maxdepth 1 -name "*.json" -exec cp {} "$INSTALL_DIR/" \; 2>/dev/null || true
find . -maxdepth 1 -name "*.yaml" -exec cp {} "$INSTALL_DIR/" \; 2>/dev/null || true
find . -maxdepth 1 -name "*.yml" -exec cp {} "$INSTALL_DIR/" \; 2>/dev/null || true

# Copy text files
find . -maxdepth 1 -name "*.txt" -exec cp {} "$INSTALL_DIR/" \; 2>/dev/null || true
find . -maxdepth 1 -name "*.md" -exec cp {} "$INSTALL_DIR/" \; 2>/dev/null || true

# Copy directories
if [ -d "./modules" ]; then
    cp -r ./modules "$INSTALL_DIR/"
fi
if [ -d "./utils" ]; then
    cp -r ./utils "$INSTALL_DIR/"
fi
if [ -d "./templates" ]; then
    cp -r ./templates "$INSTALL_DIR/"
fi
if [ -d "./static" ]; then
    cp -r ./static "$INSTALL_DIR/"
fi
if [ -d "./plugins" ]; then
    cp -r ./plugins "$INSTALL_DIR/"
fi
if [ -d "./hotkeys" ]; then
    cp -r ./hotkeys "$INSTALL_DIR/"
fi

# Make sure main entry point exists
if [ ! -f "$INSTALL_DIR/maysie.py" ] && [ -f "./main.py" ]; then
    cp ./main.py "$INSTALL_DIR/maysie.py"
elif [ ! -f "$INSTALL_DIR/maysie.py" ] && [ -f "./maysie.py" ]; then
    cp ./maysie.py "$INSTALL_DIR/"
fi

# Create hotkey configuration file
print_status "Creating hotkey configuration..."
cat > "$INSTALL_DIR/hotkeys/default.json" << EOF
{
    "version": "1.0",
    "hotkeys": {
        "activate": {
            "description": "Activate Maysie AI Assistant",
            "key": "$ACTIVATE_HOTKEY",
            "enabled": true,
            "action": "activate"
        },
        "screenshot": {
            "description": "Take screenshot and analyze",
            "key": "$SCREENSHOT_HOTKEY",
            "enabled": true,
            "action": "screenshot"
        },
        "quit": {
            "description": "Quit Maysie",
            "key": "$QUIT_HOTKEY",
            "enabled": true,
            "action": "quit"
        },
        "toggle_debug": {
            "description": "Toggle debug mode",
            "key": "ctrl+alt+d",
            "enabled": true,
            "action": "toggle_debug"
        },
        "quick_note": {
            "description": "Quick note taker",
            "key": "ctrl+alt+n",
            "enabled": true,
            "action": "quick_note"
        },
        "clipboard_history": {
            "description": "Show clipboard history",
            "key": "ctrl+alt+v",
            "enabled": true,
            "action": "clipboard_history"
        }
    },
    "voice_commands": {
        "debug_mode": "$DEBUG_COMMAND",
        "activate": "hey maysie",
        "stop": "stop listening",
        "screenshot": "take screenshot"
    }
}
EOF

# Create xbindkeys configuration for global hotkeys
print_status "Creating global hotkey configuration..."
cat > "$CURRENT_HOME/.xbindkeysrc" << EOF
# Maysie AI Assistant Hotkeys
# Generated by installation script

# Activate Maysie - $ACTIVATE_HOTKEY
"$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/hotkey_handler.py activate"
  $ACTIVATE_HOTKEY

# Screenshot - $SCREENSHOT_HOTKEY
"$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/hotkey_handler.py screenshot"
  $SCREENSHOT_HOTKEY

# Quit - $QUIT_HOTKEY
"$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/hotkey_handler.py quit"
  $QUIT_HOTKEY
EOF

chown $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.xbindkeysrc"

# Create hotkey handler script if it doesn't exist
if [ ! -f "$INSTALL_DIR/hotkey_handler.py" ]; then
    cat > "$INSTALL_DIR/hotkey_handler.py" << 'EOF'
#!/usr/bin/env python3
"""
Hotkey handler for Maysie AI Assistant
Handles global hotkey events and communicates with the main Maysie process
"""

import sys
import os
import dbus
import argparse
from pathlib import Path

def send_dbus_signal(action):
    """Send a signal to Maysie via DBus"""
    try:
        bus = dbus.SessionBus()
        proxy = bus.get_object('com.maysie.ai', '/com/maysie/ai')
        iface = dbus.Interface(proxy, 'com.maysie.ai')
        
        if action == "activate":
            iface.Activate()
            print("Sent activate signal")
        elif action == "screenshot":
            iface.Screenshot()
            print("Sent screenshot signal")
        elif action == "quit":
            iface.Quit()
            print("Sent quit signal")
        elif action == "toggle_debug":
            iface.ToggleDebug()
            print("Sent toggle debug signal")
        else:
            print(f"Unknown action: {action}")
            
    except dbus.exceptions.DBusException as e:
        print(f"DBus error: {e}")
        print("Make sure Maysie is running and DBus service is available")
    except Exception as e:
        print(f"Error: {e}")

def main():
    parser = argparse.ArgumentParser(description='Maysie Hotkey Handler')
    parser.add_argument('action', choices=['activate', 'screenshot', 'quit', 'toggle_debug'],
                       help='Action to perform')
    
    args = parser.parse_args()
    send_dbus_signal(args.action)

if __name__ == "__main__":
    main()
EOF
    chmod +x "$INSTALL_DIR/hotkey_handler.py"
fi

# Copy requirements if exists
if [ -f "./requirements.txt" ]; then
    cp ./requirements.txt "$INSTALL_DIR/"
else
    # Create default requirements
    cat > "$INSTALL_DIR/requirements.txt" << 'EOF'
aiohttp==3.9.0
asyncio==3.4.3
cryptography==41.0.0
PyYAML==6.0.1
pynput==1.7.6
psutil==5.9.0
Flask==3.0.0
Flask-CORS==4.0.0
Werkzeug==3.0.0
openai==1.3.0
google-generativeai==0.3.0
anthropic==0.7.0
python-daemon==3.0.1
dbus-python==1.3.2
python-dotenv==1.0.0
requests==2.31.0
jsonschema==4.20.0
colorama==0.4.6
python-dateutil==2.8.2
protobuf==4.25.8
grpcio==1.76.0
grpcio-status==1.62.3
google-api-core==2.29.0
google-auth==2.48.0
googleapis-common-protos==1.72.0
tokenizers==0.22.2
huggingface-hub==1.3.7
httpx==0.28.1
anyio==3.7.1
pydantic==2.12.5
tqdm==4.67.2
typing-extensions==4.15.0
packaging==26.0
xlib==0.21
python-xlib==0.33
pyautogui==0.9.54
pillow==10.4.0
EOF
fi

# Set permissions
chmod 755 "$INSTALL_DIR"/*.py 2>/dev/null || true
chmod 644 "$INSTALL_DIR"/*.txt 2>/dev/null || true
chmod 644 "$INSTALL_DIR"/*.json 2>/dev/null || true
chmod -R 755 "$INSTALL_DIR/modules" 2>/dev/null || true
chmod -R 755 "$INSTALL_DIR/utils" 2>/dev/null || true
chmod -R 755 "$INSTALL_DIR/hotkeys" 2>/dev/null || true

print_success "Files copied"

# Install Python dependencies
print_status "Installing Python dependencies..."
cd "$INSTALL_DIR"

# Create virtual environment
print_status "Creating virtual environment..."
sudo -u $CURRENT_USER python3 -m venv venv --system-site-packages
print_success "Virtual environment created"

# Activate virtual environment and install dependencies
print_status "Activating virtual environment..."
source venv/bin/activate

print_status "Upgrading pip and setuptools..."
pip install --upgrade pip setuptools wheel packaging

# Check for PyGObject
print_status "Checking for PyGObject..."
if ! python3 -c "import gi" 2>/dev/null; then
    print_warning "PyGObject not found, installing..."
    print_status "Installing PyGObject via alternative method..."
    
    # Try system packages first
    apt-get install -y python3-gi python3-gi-cairo python3-cairo python3-cairo-dev
    
    # Then install in virtual environment with proper flags
    print_status "Building PyGObject from source (this may take a few minutes)..."
    pip install --no-build-isolation --no-cache-dir pycairo
    pip install --no-build-isolation --no-cache-dir PyGObject
    
    # Verify installation
    if python3 -c "import gi; print('PyGObject import successful')" 2>/dev/null; then
        print_success "PyGObject installed successfully"
    else
        print_warning "PyGObject installation may have issues, but continuing..."
    fi
else
    print_success "PyGObject already available"
fi

# Install other dependencies
print_status "Installing other dependencies..."
if [ -f "requirements.txt" ]; then
    # Try 3 times in case of network issues
    for i in {1..3}; do
        print_status "Attempt $i of 3..."
        if pip install -r requirements.txt --no-cache-dir; then
            print_success "All dependencies installed successfully"
            break
        elif [ $i -eq 3 ]; then
            print_warning "Some dependencies may have failed, continuing with basic set..."
            # Install minimal set
            pip install aiohttp cryptography pynput psutil Flask openai python-dotenv requests dbus-python pillow pyautogui
        fi
        sleep 2
    done
else
    print_warning "requirements.txt not found, installing common dependencies..."
    pip install aiohttp cryptography pynput psutil Flask openai python-dotenv requests dbus-python pillow pyautogui
fi

# Verify critical packages
print_status "Verifying critical packages..."
CRITICAL_PACKAGES=(
    "gi"
    "dbus"
    "pynput.keyboard"
    "pynput.mouse"
    "aiohttp"
    "cryptography"
    "flask"
    "openai"
    "PIL"
    "pyautogui"
)

ALL_OK=true
for package in "${CRITICAL_PACKAGES[@]}"; do
    if python3 -c "import ${package%%\.*} 2>/dev/null; print('${package%%\.*} import test')" >/dev/null 2>&1; then
        print_success "$package import successful"
    else
        print_warning "$package import failed"
        ALL_OK=false
    fi
done

if [ "$ALL_OK" = true ]; then
    print_success "All critical packages verified"
else
    print_warning "Some packages may need manual attention"
    print_warning "Maysie might still work, but some features may be limited"
fi

deactivate
print_success "Python dependencies installation completed"

# Set up Python path
print_status "Setting up Python path..."
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
cat > "$INSTALL_DIR/.env" << EOF
PYTHONPATH=$INSTALL_DIR:$INSTALL_DIR/venv/lib/python$PYTHON_VERSION/site-packages
MAYSIE_HOME=$INSTALL_DIR
MAYSIE_CONFIG=$CONFIG_DIR
MAYSIE_LOG=$LOG_DIR
DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $CURRENT_USER)/bus
DISPLAY=:0
XAUTHORITY=$CURRENT_HOME/.Xauthority
MAYSIE_HOTKEY_ACTIVATE=$ACTIVATE_HOTKEY
MAYSIE_HOTKEY_SCREENSHOT=$SCREENSHOT_HOTKEY
MAYSIE_HOTKEY_QUIT=$QUIT_HOTKEY
EOF

chown $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR/.env"
print_success "Python path configured in virtual environment"

# Set up systemd service
print_status "Setting up systemd service..."
# First, ensure the temporary directory exists
mkdir -p "$TEMP_DIR"
chmod 1777 "$TEMP_DIR"

cat > /etc/systemd/system/maysie.service << EOF
[Unit]
Description=Maysie AI Assistant
After=network.target
After=dbus.service
Requires=dbus.service
Wants=network-online.target
After=network-online.target
ConditionPathExists=$INSTALL_DIR/maysie.py

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
EnvironmentFile=$INSTALL_DIR/.env
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/maysie.py
ExecStartPost=/usr/bin/xbindkeys
Restart=on-failure
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

# Logging
StandardOutput=journal
StandardError=journal
SyslogIdentifier=maysie

# Security (commented out PrivateTmp to avoid issues with missing directory)
# PrivateTmp=true
# PrivateMounts=true
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=$LOG_DIR $CONFIG_DIR $INSTALL_DIR $INSTALL_DIR/data $INSTALL_DIR/cache
ProtectHome=read-only
ReadWritePaths=$TEMP_DIR

# Resource limits
MemoryHigh=2G
MemoryMax=4G
CPUQuota=200%

[Install]
WantedBy=multi-user.target
EOF

# Also create a user service for xbindkeys
cat > "$CURRENT_HOME/.config/systemd/user/xbindkeys.service" << EOF
[Unit]
Description=XBindKeys Hotkey Daemon
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/xbindkeys -f %h/.xbindkeysrc -n
Restart=on-failure
RestartSec=5

[Install]
WantedBy=graphical-session.target
EOF

chown -R $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.config/systemd"

systemctl daemon-reload
systemctl enable maysie.service
sudo -u $CURRENT_USER systemctl --user daemon-reload
sudo -u $CURRENT_USER systemctl --user enable xbindkeys.service
print_success "Systemd services configured"

# Create default configuration with custom hotkeys
print_status "Creating default configuration..."
cat > "$CONFIG_DIR/config.yaml" << EOF
# Maysie Configuration
version: 1.0

# AI Settings
ai:
  default_provider: "openai"
  providers:
    openai:
      enabled: true
      model: "gpt-4"
      temperature: 0.7
      max_tokens: 1000
    anthropic:
      enabled: true
      model: "claude-3-opus-20240229"
      temperature: 0.7
      max_tokens: 1000
    google:
      enabled: true
      model: "gemini-pro"
      temperature: 0.7
      max_tokens: 1000

# API Keys (configure via web interface or debug mode)
api_keys:
  openai: ""
  anthropic: ""
  google: ""

# Hotkey Settings
hotkeys:
  activate: "$ACTIVATE_HOTKEY"
  screenshot: "$SCREENSHOT_HOTKEY"
  quit: "$QUIT_HOTKEY"
  debug_mode: "$DEBUG_COMMAND"
  custom_commands:
    - name: "Toggle Debug"
      key: "ctrl+alt+d"
      command: "toggle_debug"
    - name: "Quick Note"
      key: "ctrl+alt+n"
      command: "quick_note"
    - name: "Clipboard History"
      key: "ctrl+alt+v"
      command: "clipboard_history"

# Web Interface
web:
  enabled: true
  host: "127.0.0.1"
  port: 7777
  debug: false
  ssl: false
  cors_origins: ["http://localhost:7777", "http://127.0.0.1:7777"]

# Features
features:
  clipboard_monitor: true
  screenshot_ocr: true
  auto_update: false
  voice_input: false
  file_upload: true
  plugin_system: true
  hotkeys_enabled: true
  
  # OCR settings
  ocr:
    enabled: true
    language: "eng"
    engine: "tesseract"
  
  # Screenshot settings
  screenshot:
    format: "png"
    quality: 85
    delay: 0.5

# Database
database:
  type: "sqlite"
  path: "/opt/maysie/data/maysie.db"
  backup_count: 5
  backup_interval: "daily"

# Logging
logging:
  level: "INFO"
  console_level: "INFO"
  file_level: "DEBUG"
  file_path: "/var/log/maysie/maysie.log"
  max_size: 10485760  # 10MB
  backup_count: 5
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"

# Performance
performance:
  worker_count: 2
  max_requests: 100
  timeout: 30
  cache_size: 100
  cache_ttl: 300

# Security
security:
  encryption_enabled: true
  debug_mode_password: "changeme"
  session_timeout: 3600
  max_login_attempts: 3
  require_authentication: false

# Paths
paths:
  install: "/opt/maysie"
  config: "/etc/maysie"
  logs: "/var/log/maysie"
  data: "/opt/maysie/data"
  cache: "/opt/maysie/cache"
  plugins: "/opt/maysie/plugins"
  temp: "/tmp/maysie"
  hotkeys: "/opt/maysie/hotkeys"
EOF

chown $CURRENT_USER:$CURRENT_USER "$CONFIG_DIR/config.yaml"
chmod 600 "$CONFIG_DIR/config.yaml"
print_success "Default configuration created"

# Create encryption key
print_status "Creating encryption key..."
ENCRYPTION_KEY=$(openssl rand -hex 32)
SESSION_SECRET=$(openssl rand -hex 32)

cat > "$CONFIG_DIR/secrets.env" << EOF
# Encryption key for sensitive data
ENCRYPTION_KEY=$ENCRYPTION_KEY
SESSION_SECRET=$SESSION_SECRET

# Add API keys here or use the web interface
# OPENAI_API_KEY=your_key_here
# ANTHROPIC_API_KEY=your_key_here
# GOOGLE_API_KEY=your_key_here
# AZURE_OPENAI_API_KEY=your_key_here
# AZURE_OPENAI_ENDPOINT=your_endpoint_here

# Database credentials (if using external database)
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=maysie
# DB_USER=maysie_user
# DB_PASSWORD=your_password

# Web interface credentials
# WEB_USERNAME=admin
# WEB_PASSWORD=admin
EOF

chown $CURRENT_USER:$CURRENT_USER "$CONFIG_DIR/secrets.env"
chmod 600 "$CONFIG_DIR/secrets.env"
print_success "Encryption key created"

# Create database directory and initial database
print_status "Setting up database..."
mkdir -p "$INSTALL_DIR/data"
cat > "$INSTALL_DIR/data/init.sql" << 'EOF'
CREATE TABLE IF NOT EXISTS conversations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id TEXT UNIQUE,
    title TEXT,
    model TEXT,
    provider TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id TEXT,
    role TEXT CHECK(role IN ('user', 'assistant', 'system')),
    content TEXT,
    tokens INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (conversation_id) REFERENCES conversations(conversation_id)
);

CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS api_keys (
    provider TEXT PRIMARY KEY,
    key_hash TEXT,
    last_used TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS hotkey_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hotkey TEXT,
    action TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_messages_conversation ON messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_conversations_updated ON conversations(updated_at);
CREATE INDEX IF NOT EXISTS idx_hotkey_logs_timestamp ON hotkey_logs(timestamp);
EOF

chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR/data"
print_success "Database setup completed"

# Set up log rotation
print_status "Setting up log rotation..."
cat > /etc/logrotate.d/maysie << EOF
$LOG_DIR/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 640 $CURRENT_USER $CURRENT_USER
    sharedscripts
    postrotate
        systemctl reload maysie.service > /dev/null 2>&1 || true
    endscript
}
EOF

chmod 644 /etc/logrotate.d/maysie
print_success "Log rotation configured"

# Create startup script for user with hotkey info
print_status "Creating user startup script..."
cat > "$CURRENT_HOME/.local/bin/maysie-start" << EOF
#!/bin/bash
# User script to start Maysie manually

echo "Maysie AI Assistant"
echo "=================="

if systemctl is-active --quiet maysie.service; then
    echo "Maysie is already running."
    echo ""
    echo "Hotkeys configured:"
    echo "  Activate:    $ACTIVATE_HOTKEY"
    echo "  Screenshot:  $SCREENSHOT_HOTKEY"
    echo "  Quit:        $QUIT_HOTKEY"
    echo "  Debug mode:  Type '$DEBUG_COMMAND' in the chat"
    echo ""
    echo "Web interface: http://127.0.0.1:7777"
    echo "Press $ACTIVATE_HOTKEY to activate"
    exit 0
fi

echo "Starting Maysie..."
sudo systemctl start maysie.service
sudo -u $CURRENT_USER systemctl --user start xbindkeys.service

sleep 2

if systemctl is-active --quiet maysie.service; then
    echo ""
    echo "Maysie started successfully!"
    echo ""
    echo "Hotkeys configured:"
    echo "  Activate:    $ACTIVATE_HOTKEY"
    echo "  Screenshot:  $SCREENSHOT_HOTKEY"
    echo "  Quit:        $QUIT_HOTKEY"
    echo "  Debug mode:  Type '$DEBUG_COMMAND' in the chat"
    echo ""
    echo "Web interface: http://127.0.0.1:7777"
    echo "Press $ACTIVATE_HOTKEY to activate"
else
    echo "Failed to start Maysie. Check logs with:"
    echo "sudo journalctl -u maysie.service -f"
fi
EOF

chmod +x "$CURRENT_HOME/.local/bin/maysie-start"
chown $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.local/bin/maysie-start"

# Create hotkey test script
cat > "$CURRENT_HOME/.local/bin/test-hotkeys" << 'EOF'
#!/bin/bash
echo "Testing hotkey configuration..."
echo "Current hotkeys in ~/.xbindkeysrc:"
echo ""
grep -v "^#" ~/.xbindkeysrc | grep -v "^$"
echo ""
echo "To test hotkeys, make sure xbindkeys is running:"
echo "  ps aux | grep xbindkeys"
echo ""
echo "To restart xbindkeys:"
echo "  killall xbindkeys && xbindkeys"
echo ""
echo "To view hotkey events in real-time:"
echo "  tail -f /var/log/maysie/maysie.log | grep -i hotkey"
EOF

chmod +x "$CURRENT_HOME/.local/bin/test-hotkeys"
chown $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.local/bin/test-hotkeys"

print_success "User scripts created"

# Test installation
print_status "Testing installation..."
echo "Testing Python imports..."
cd "$INSTALL_DIR"
source venv/bin/activate

echo "Python version: $(python3 --version)"
echo "Python path: $(python3 -c 'import sys; print(\":\".join(sys.path[:3]))')"

# Test imports
TEST_IMPORTS=(
    "gi"
    "dbus"
    "pynput.keyboard"
    "pynput.mouse"
    "aiohttp"
    "cryptography"
    "flask"
    "openai"
    "PIL.Image as Image"
    "pyautogui"
    "yaml"
)

echo ""
echo "Import test results:"
for import in "${TEST_IMPORTS[@]}"; do
    # Extract module name for display
    module=$(echo "$import" | awk '{print $1}')
    if python3 -c "import $import" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $module"
    else
        echo -e "  ${RED}✗${NC} $module"
    fi
done

deactivate

# Test hotkey configuration
print_status "Testing hotkey configuration..."
if command -v xbindkeys >/dev/null 2>&1; then
    # Kill any existing xbindkeys
    killall xbindkeys 2>/dev/null || true
    # Start xbindkeys in background
    sudo -u $CURRENT_USER xbindkeys -f "$CURRENT_HOME/.xbindkeysrc" &
    sleep 1
    if pgrep -x "xbindkeys" >/dev/null; then
        print_success "xbindkeys started successfully"
    else
        print_warning "xbindkeys failed to start, hotkeys may not work"
    fi
else
    print_warning "xbindkeys not found, hotkeys will not work globally"
fi

# Test systemd service
print_status "Testing systemd service..."
systemctl daemon-reload
print_success "Systemd daemon reloaded"

print_success "Installation test completed"

# Start service
print_status "Starting Maysie service..."
systemctl start maysie.service
sleep 3

if systemctl is-active --quiet maysie.service; then
    print_success "Maysie service started successfully"
    SERVICE_STATUS=$(systemctl status maysie.service --no-pager | grep -A 3 "Active:")
    print_status "Service status:"
    echo "  $SERVICE_STATUS"
else
    print_warning "Service is not active, checking logs..."
    journalctl -u maysie.service --no-pager -n 10
    print_warning "Service startup had issues"
    print_warning "Please check the logs and run: sudo systemctl status maysie"
fi

# Final message
echo ""
echo "================================================"
echo "  Installation Complete!"
echo "================================================"
echo ""
echo "Maysie AI Assistant is now installed with the following hotkeys:"
echo ""
echo -e "  ${GREEN}Primary Hotkeys:${NC}"
echo "  ─────────────────────────────"
echo "  Activate Maysie:    ${YELLOW}$ACTIVATE_HOTKEY${NC}"
echo "  Take Screenshot:    ${YELLOW}$SCREENSHOT_HOTKEY${NC}"
echo "  Quit Maysie:        ${YELLOW}$QUIT_HOTKEY${NC}"
echo ""
echo -e "  ${GREEN}Additional Hotkeys:${NC}"
echo "  ─────────────────────────────"
echo "  Toggle Debug Mode:  ${YELLOW}Ctrl+Alt+D${NC}"
echo "  Quick Note:         ${YELLOW}Ctrl+Alt+N${NC}"
echo "  Clipboard History:  ${YELLOW}Ctrl+Alt+V${NC}"
echo ""
echo -e "  ${GREEN}Voice Commands:${NC}"
echo "  ─────────────────────────────"
echo "  Debug Mode:         Type '${YELLOW}$DEBUG_COMMAND${NC}' in chat"
echo ""
echo -e "  ${GREEN}Quick Start:${NC}"
echo "  ─────────────────────────────"
echo "  1. Press ${YELLOW}$ACTIVATE_HOTKEY${NC} to open Maysie"
echo "  2. Type '${YELLOW}$DEBUG_COMMAND changeme${NC}' to enter debug mode"
echo "  3. Configure AI API keys at ${YELLOW}http://127.0.0.1:7777${NC}"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status maysie      - Check service status"
echo "  sudo journalctl -u maysie.service -f - View logs"
echo "  sudo systemctl restart maysie     - Restart service"
echo "  sudo systemctl stop maysie        - Stop service"
echo "  maysie-start                      - Start as user (if not running)"
echo "  test-hotkeys                      - Test hotkey configuration"
echo ""
echo "Installation directories:"
echo "  Application: $INSTALL_DIR"
echo "  Configuration: $CONFIG_DIR"
echo "  Logs: $LOG_DIR"
echo "  Data: $INSTALL_DIR/data"
echo ""
echo "Troubleshooting hotkeys:"
echo "  If hotkeys don't work, try:"
echo "  1. Run: test-hotkeys"
echo "  2. Restart xbindkeys: killall xbindkeys && xbindkeys"
echo "  3. Check if another app is using the same hotkey"
echo "  4. Edit hotkeys in: ~/.xbindkeysrc"
echo ""
echo "To change hotkeys later:"
echo "  1. Edit ~/.xbindkeysrc"
echo "  2. Edit $CONFIG_DIR/config.yaml"
echo "  3. Restart: sudo systemctl restart maysie"
echo "  4. Restart xbindkeys: killall xbindkeys && xbindkeys"
echo ""
echo "For more information, visit:"
echo "https://github.com/Manjil740/maysie"
echo ""

# Cleanup
print_status "Cleaning up temporary files..."
rm -rf /tmp/pip-* /tmp/build-* 2>/dev/null || true
print_success "Cleanup complete"

echo ""
print_success "Maysie AI Assistant installation completed successfully!"
echo ""

exit 0