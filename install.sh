#!/bin/bash
# Maysie Installation Script
# Supports: Debian/Ubuntu, Fedora, Arch, openSUSE

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Maysie AI Assistant - Installation${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Get the actual user (not root)
ACTUAL_USER="${SUDO_USER:-$(whoami)}"
ACTUAL_HOME=$(eval echo ~$ACTUAL_USER)

echo -e "${YELLOW}Installing for user: $ACTUAL_USER${NC}"
echo ""

# Detect distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        DISTRO_VERSION=$VERSION_ID
    else
        echo -e "${RED}Cannot detect distribution${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Detected: $PRETTY_NAME${NC}"
}

# Install system dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing system dependencies...${NC}"
    
    case $DISTRO in
        ubuntu|debian)
            echo -e "${YELLOW}Updating package list...${NC}"
            apt-get update
            echo -e "${YELLOW}Installing core dependencies...${NC}"
            apt-get install -y \
                python3 \
                python3-pip \
                python3-venv \
                python3-dev \
                python3-gi \
                python3-gi-cairo \
                gir1.2-gtk-3.0 \
                gir1.2-glib-2.0 \
                python3-cairo \
                python3-cairo-dev \
                libcairo2-dev \
                libgirepository1.0-dev \
                gobject-introspection \
                gobject-introspection-1.0 \
                libgirepository-1.0-1 \
                pkg-config \
                build-essential \
                curl \
                wget \
                git \
                xclip \
                dbus \
                libdbus-1-dev \
                libdbus-glib-1-dev \
                sudo \
                systemd \
                ca-certificates \
                libffi-dev \
                libssl-dev
            ;;
        fedora|rhel|centos)
            echo -e "${YELLOW}Installing core dependencies...${NC}"
            dnf install -y \
                python3 \
                python3-pip \
                python3-devel \
                python3-gobject \
                gtk3 \
                cairo \
                cairo-devel \
                cairo-gobject-devel \
                gobject-introspection-devel \
                gobject-introspection \
                gcc \
                gcc-c++ \
                make \
                curl \
                wget \
                git \
                xclip \
                dbus \
                dbus-devel \
                dbus-glib-devel \
                sudo \
                systemd \
                ca-certificates \
                libffi-devel \
                openssl-devel
            ;;
        arch|manjaro)
            echo -e "${YELLOW}Installing core dependencies...${NC}"
            pacman -Sy --noconfirm \
                python \
                python-pip \
                python-virtualenv \
                python-gobject \
                gtk3 \
                cairo \
                gobject-introspection \
                gobject-introspection-runtime \
                base-devel \
                curl \
                wget \
                git \
                xclip \
                dbus \
                dbus-glib \
                sudo \
                systemd \
                ca-certificates \
                libffi \
                openssl
            ;;
        opensuse*|sles)
            echo -e "${YELLOW}Installing core dependencies...${NC}"
            zypper install -y \
                python3 \
                python3-pip \
                python3-venv \
                python3-devel \
                python3-gobject \
                typelib-1_0-Gtk-3_0 \
                typelib-1_0-GLib-2_0 \
                python3-cairo \
                cairo-devel \
                gobject-introspection-devel \
                gobject-introspection \
                gcc \
                gcc-c++ \
                make \
                curl \
                wget \
                git \
                xclip \
                dbus-1 \
                dbus-1-devel \
                dbus-1-glib-devel \
                sudo \
                systemd \
                ca-certificates \
                libffi-devel \
                libopenssl-devel
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO${NC}"
            echo -e "${YELLOW}Trying to install generic dependencies...${NC}"
            # Try generic installation
            if command -v apt-get &> /dev/null; then
                apt-get update
                apt-get install -y python3 python3-pip python3-venv python3-dev python3-gi gir1.2-glib-2.0
            elif command -v dnf &> /dev/null; then
                dnf install -y python3 python3-pip python3-devel python3-gobject gobject-introspection
            elif command -v yum &> /dev/null; then
                yum install -y python3 python3-pip python3-devel python3-gobject gobject-introspection
            elif command -v pacman &> /dev/null; then
                pacman -Sy --noconfirm python python-pip python-virtualenv python-gobject gobject-introspection
            elif command -v zypper &> /dev/null; then
                zypper install -y python3 python3-pip python3-venv python3-devel python3-gobject gobject-introspection
            else
                echo -e "${RED}Could not find a supported package manager${NC}"
                exit 1
            fi
            ;;
    esac
    
    echo -e "${GREEN}✓ System dependencies installed${NC}"
}

# Verify Python version
verify_python() {
    echo -e "${YELLOW}Verifying Python version...${NC}"
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2)
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)
    
    if [ $PYTHON_MAJOR -lt 3 ] || ([ $PYTHON_MAJOR -eq 3 ] && [ $PYTHON_MINOR -lt 9 ]); then
        echo -e "${RED}Error: Python 3.9+ is required. Found Python $PYTHON_VERSION${NC}"
        echo -e "${YELLOW}Please upgrade Python and try again.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Python $PYTHON_VERSION detected${NC}"
}

# Create directories
create_directories() {
    echo -e "${YELLOW}Creating directories...${NC}"
    
    mkdir -p /opt/maysie
    mkdir -p /etc/maysie
    mkdir -p /var/log/maysie
    mkdir -p /usr/share/maysie
    mkdir -p /tmp/maysie
    
    # Set permissions
    chown -R $ACTUAL_USER:$ACTUAL_USER /opt/maysie
    chown -R $ACTUAL_USER:$ACTUAL_USER /var/log/maysie
    chown -R $ACTUAL_USER:$ACTUAL_USER /etc/maysie
    chown -R $ACTUAL_USER:$ACTUAL_USER /tmp/maysie
    
    chmod 755 /opt/maysie
    chmod 755 /etc/maysie
    chmod 755 /var/log/maysie
    chmod 755 /tmp/maysie
    
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Install Python dependencies with fallback
install_python_deps() {
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    
    # Change to installation directory
    cd /opt/maysie
    
    # Check if venv already exists
    if [ ! -d "venv" ]; then
        echo -e "${YELLOW}Creating virtual environment...${NC}"
        python3 -m venv venv
    fi
    
    echo -e "${YELLOW}Activating virtual environment...${NC}"
    source venv/bin/activate
    
    # Upgrade pip and setuptools
    echo -e "${YELLOW}Upgrading pip and setuptools...${NC}"
    pip install --upgrade pip setuptools wheel
    
    # First, try to install system Python packages if available
    echo -e "${YELLOW}Checking for system Python packages...${NC}"
    
    case $DISTRO in
        ubuntu|debian)
            # On Debian/Ubuntu, prefer system packages for GTK dependencies
            apt-get install -y python3-pygi python3-pygi-cairo python3-cairo 2>/dev/null || true
            ;;
    esac
    
    # Install dependencies with specific versions that work well together
    echo -e "${YELLOW}Installing core Python packages...${NC}"
    
    # Install PyGObject first with system package if possible
    if python3 -c "import gi" 2>/dev/null; then
        echo -e "${GREEN}✓ PyGObject already available${NC}"
    else
        echo -e "${YELLOW}Installing PyGObject via pip...${NC}"
        # Try with specific version and build dependencies
        pip install pycairo==1.23.0 --no-cache-dir
        pip install PyGObject==3.42.0 --no-cache-dir || {
            echo -e "${YELLOW}PyGObject installation via pip failed, trying alternative...${NC}"
            # If pip installation fails, try to install from system
            case $DISTRO in
                ubuntu|debian)
                    apt-get install -y python3-gi python3-gi-cairo gir1.2-gtk-3.0
                    ;;
                fedora|rhel|centos)
                    dnf install -y python3-gobject python3-cairo-devel
                    ;;
                arch|manjaro)
                    pacman -Sy --noconfirm python-gobject python-cairo
                    ;;
            esac
        }
    fi
    
    # Now install the rest of the dependencies
    echo -e "${YELLOW}Installing remaining dependencies...${NC}"
    
    # Create a minimal requirements file if it doesn't exist
    if [ ! -f "/opt/maysie/requirements.txt" ]; then
        cat > /opt/maysie/requirements.txt << 'EOF'
aiohttp>=3.9.0,<4.0.0
asyncio>=3.4.3
cryptography>=41.0.0,<43.0.0
PyYAML>=6.0.1,<7.0.0
pynput>=1.7.6,<1.8.0
psutil>=5.9.0,<6.0.0
PyGObject>=3.42.0,<3.43.0
pycairo>=1.23.0,<1.24.0
Flask>=3.0.0,<3.1.0
Flask-CORS>=4.0.0,<5.0.0
Werkzeug>=3.0.0,<4.0.0
openai>=1.3.0,<1.4.0
google-generativeai>=0.3.0,<0.4.0
anthropic>=0.7.0,<0.8.0
python-daemon>=3.0.1,<3.1.0
dbus-python>=1.3.2,<1.4.0
python-dotenv>=1.0.0,<2.0.0
requests>=2.31.0,<3.0.0
jsonschema>=4.20.0,<5.0.0
EOF
    fi
    
    # Install with retry logic
    MAX_RETRIES=3
    RETRY_COUNT=0
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        echo -e "${YELLOW}Attempt $((RETRY_COUNT + 1)) of $MAX_RETRIES...${NC}"
        
        if pip install -r /opt/maysie/requirements.txt --no-cache-dir; then
            echo -e "${GREEN}✓ All dependencies installed successfully${NC}"
            break
        fi
        
        RETRY_COUNT=$((RETRY_COUNT + 1))
        
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            echo -e "${YELLOW}Installation failed, retrying in 5 seconds...${NC}"
            sleep 5
            
            # Try installing problematic packages individually
            echo -e "${YELLOW}Trying individual package installation...${NC}"
            pip install aiohttp==3.9.0 --no-cache-dir || true
            pip install cryptography==41.0.0 --no-cache-dir || true
            pip install PyYAML==6.0.1 --no-cache-dir || true
        else
            echo -e "${YELLOW}⚠ Some packages failed to install, continuing anyway...${NC}"
        fi
    done
    
    # Install additional useful packages
    echo -e "${YELLOW}Installing additional utilities...${NC}"
    pip install colorama==0.4.6 python-dateutil==2.8.2 --no-cache-dir || true
    
    # Verify critical packages
    echo -e "${YELLOW}Verifying critical packages...${NC}"
    
    CRITICAL_PACKAGES=("gi" "dbus" "pynput" "aiohttp" "cryptography")
    ALL_GOOD=true
    
    for package in "${CRITICAL_PACKAGES[@]}"; do
        if python3 -c "import $package" 2>/dev/null; then
            echo -e "${GREEN}✓ $package import successful${NC}"
        else
            echo -e "${YELLOW}⚠ $package import failed${NC}"
            ALL_GOOD=false
        fi
    done
    
    if $ALL_GOOD; then
        echo -e "${GREEN}✓ All critical packages verified${NC}"
    else
        echo -e "${YELLOW}⚠ Some packages may need manual attention${NC}"
        echo -e "${YELLOW}  Maysie might still work, but some features may be limited${NC}"
    fi
    
    deactivate
    
    echo -e "${GREEN}✓ Python dependencies installation completed${NC}"
}

# Copy files
copy_files() {
    echo -e "${YELLOW}Copying application files...${NC}"
    
    # Get the source directory (where install.sh is located)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check if we're running from the source directory
    if [ ! -f "$SCRIPT_DIR/maysie/__init__.py" ] && [ ! -d "$SCRIPT_DIR/maysie" ]; then
        echo -e "${RED}Error: Cannot find Maysie source files${NC}"
        echo -e "${YELLOW}Please run this script from the Maysie directory${NC}"
        exit 1
    fi
    
    # Clear existing installation
    echo -e "${YELLOW}Cleaning up previous installation...${NC}"
    rm -rf /opt/maysie/maysie 2>/dev/null || true
    
    # Copy the entire maysie directory structure
    echo -e "${YELLOW}Copying source files...${NC}"
    if [ -d "$SCRIPT_DIR/maysie" ]; then
        cp -r "$SCRIPT_DIR/maysie" /opt/maysie/
    else
        # If maysie directory doesn't exist, create structure
        mkdir -p /opt/maysie/maysie
        # Copy individual files if they exist
        for file in "$SCRIPT_DIR"/*.py; do
            [ -f "$file" ] && cp "$file" /opt/maysie/maysie/ 2>/dev/null || true
        done
    fi
    
    # Copy requirements.txt if it exists
    if [ -f "$SCRIPT_DIR/requirements.txt" ]; then
        cp "$SCRIPT_DIR/requirements.txt" /opt/maysie/
    fi
    
    # Copy service file if it exists
    if [ -f "$SCRIPT_DIR/maysie.service" ]; then
        cp "$SCRIPT_DIR/maysie.service" /opt/maysie/
    fi
    
    # Make Python files readable
    find /opt/maysie -name "*.py" -exec chmod 644 {} \; 2>/dev/null || true
    
    # Set permissions
    chown -R $ACTUAL_USER:$ACTUAL_USER /opt/maysie
    
    echo -e "${GREEN}✓ Files copied${NC}"
}

# Setup Python path
setup_python_path() {
    echo -e "${YELLOW}Setting up Python path...${NC}"
    
    # Get Python version
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d. -f1,2)
    
    # Create .pth file in venv
    VENV_SITE_PACKAGES="/opt/maysie/venv/lib/python$PYTHON_VERSION/site-packages"
    
    if [ -d "$VENV_SITE_PACKAGES" ]; then
        echo "/opt/maysie" > "$VENV_SITE_PACKAGES/maysie.pth"
        echo -e "${GREEN}✓ Python path configured in virtual environment${NC}"
    else
        echo -e "${YELLOW}⚠ Could not find virtual environment site-packages${NC}"
    fi
}

# Setup systemd service
setup_service() {
    echo -e "${YELLOW}Setting up systemd service...${NC}"
    
    SERVICE_FILE="/etc/systemd/system/maysie.service"
    
    # Create service file
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Maysie AI Assistant
After=network.target dbus.service graphical-session.target
Wants=network.target dbus.service

[Service]
Type=simple
User=$ACTUAL_USER
Group=$ACTUAL_USER
WorkingDirectory=/opt/maysie
Environment="DISPLAY=:0"
Environment="XAUTHORITY=/home/$ACTUAL_USER/.Xauthority"
Environment="DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $ACTUAL_USER)/bus"
Environment="PATH=/opt/maysie/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="PYTHONPATH=/opt/maysie"
ExecStart=/opt/maysie/venv/bin/python3 -m maysie.core.service
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal
SyslogIdentifier=maysie

# Security
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ReadWritePaths=/var/log/maysie /etc/maysie /tmp/maysie /home/$ACTUAL_USER/.config

[Install]
WantedBy=default.target
EOF
    
    # Set permissions
    chmod 644 "$SERVICE_FILE"
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Systemd service configured${NC}"
}

# Create default config
create_config() {
    echo -e "${YELLOW}Creating default configuration...${NC}"
    
    CONFIG_FILE="/etc/maysie/config.yaml"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << EOF
# Maysie Configuration
hotkey:
  combination: "Super+Alt+A"
  enabled: true

ai:
  default_provider: "auto"
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
  timeout: 30
  max_retries: 3

sudo:
  cache_timeout: 300
  require_confirmation: true
  dangerous_commands:
    - "rm -rf /"
    - "mkfs"
    - "dd if=/dev/zero"
    - ":(){:|:&};:"

ui:
  position: "bottom-right"
  theme: "dark"
  auto_hide_delay: 3
  width: 400
  height: 150
  opacity: 0.95

response:
  default_style: "short"
  styles:
    short: "Provide a concise, direct answer. 2-3 sentences max."
    detailed: "Provide a comprehensive, well-explained answer with examples."
    bullets: "Provide answer as clear bullet points."
    technical: "Provide detailed technical explanation with proper terminology."

logging:
  level: "INFO"
  max_file_size_mb: 10
  backup_count: 5
  enable_debug: false

web_ui:
  enabled: true
  host: "127.0.0.1"
  port: 7777
  auth_required: true
EOF
        
        # Set permissions
        chown $ACTUAL_USER:$ACTUAL_USER "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        
        echo -e "${GREEN}✓ Default configuration created${NC}"
    else
        echo -e "${GREEN}✓ Existing configuration preserved${NC}"
    fi
    
    # Create empty API key file with secure permissions
    API_KEY_FILE="/etc/maysie/api_keys.enc"
    if [ ! -f "$API_KEY_FILE" ]; then
        touch "$API_KEY_FILE"
        chown $ACTUAL_USER:$ACTUAL_USER "$API_KEY_FILE"
        chmod 600 "$API_KEY_FILE"
    fi
    
    # Create encryption key file
    ENCRYPTION_KEY_FILE="/etc/maysie/.key"
    if [ ! -f "$ENCRYPTION_KEY_FILE" ]; then
        python3 -c "from cryptography.fernet import Fernet; key = Fernet.generate_key(); print(key.decode())" > "$ENCRYPTION_KEY_FILE"
        chown $ACTUAL_USER:$ACTUAL_USER "$ENCRYPTION_KEY_FILE"
        chmod 600 "$ENCRYPTION_KEY_FILE"
        echo -e "${GREEN}✓ Encryption key created${NC}"
    fi
}

# Create log rotation config
setup_log_rotation() {
    echo -e "${YELLOW}Setting up log rotation...${NC}"
    
    LOGROTATE_FILE="/etc/logrotate.d/maysie"
    
    cat > "$LOGROTATE_FILE" << EOF
/var/log/maysie/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 $ACTUAL_USER $ACTUAL_USER
    sharedscripts
}
EOF
    
    echo -e "${GREEN}✓ Log rotation configured${NC}"
}

# Enable and start service
start_service() {
    echo -e "${YELLOW}Starting Maysie service...${NC}"
    
    # Stop if already running
    systemctl stop maysie.service 2>/dev/null || true
    
    # Enable service
    systemctl enable maysie.service
    
    # Start service
    echo -e "${YELLOW}Starting service...${NC}"
    if systemctl start maysie.service; then
        echo -e "${GREEN}✓ Maysie service started successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Service failed to start${NC}"
        return 1
    fi
    
    # Wait a moment and check status
    sleep 2
    if systemctl is-active --quiet maysie.service; then
        echo -e "${GREEN}✓ Maysie is running${NC}"
    else
        echo -e "${YELLOW}⚠ Service is not active, checking logs...${NC}"
        journalctl -u maysie.service -n 20 --no-pager
        return 1
    fi
}

# Test critical functionality
test_installation() {
    echo -e "${YELLOW}Testing installation...${NC}"
    
    cd /opt/maysie
    source venv/bin/activate
    
    # Test Python imports
    echo -e "${YELLOW}Testing Python imports...${NC}"
    
    TEST_SCRIPT=$(cat << 'EOF'
import sys
print("Python version:", sys.version)
try:
    import gi
    print("✓ PyGObject import successful")
except ImportError as e:
    print(f"✗ PyGObject import failed: {e}")

try:
    import dbus
    print("✓ DBus import successful")
except ImportError as e:
    print(f"✗ DBus import failed: {e}")

try:
    import pynput
    print("✓ pynput import successful")
except ImportError as e:
    print(f"✗ pynput import failed: {e}")

try:
    import aiohttp
    print("✓ aiohttp import successful")
except ImportError as e:
    print(f"✗ aiohttp import failed: {e}")

print("\nCore functionality test complete")
EOF
    )
    
    python3 -c "$TEST_SCRIPT"
    
    deactivate
    
    echo -e "${GREEN}✓ Installation test completed${NC}"
}

# Install complete message
show_completion() {
    echo ""
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "1. Press ${GREEN}Super+Alt+A${NC} to open Maysie"
    echo -e "2. Type: ${GREEN}enter debug mode <your_password>${NC}"
    echo -e "3. Configure AI API keys in the web interface at ${GREEN}http://127.0.0.1:7777${NC}"
    echo ""
    echo -e "${YELLOW}Useful commands:${NC}"
    echo -e "  ${GREEN}sudo systemctl status maysie${NC}  - Check service status"
    echo -e "  ${GREEN}sudo journalctl -u maysie.service -f${NC} - View logs"
    echo -e "  ${GREEN}sudo systemctl restart maysie${NC} - Restart service"
    echo -e "  ${GREEN}sudo systemctl stop maysie${NC}    - Stop service"
    echo ""
    echo -e "${YELLOW}Installation directory:${NC} ${GREEN}/opt/maysie${NC}"
    echo -e "${YELLOW}Configuration directory:${NC} ${GREEN}/etc/maysie${NC}"
    echo -e "${YELLOW}Log directory:${NC} ${GREEN}/var/log/maysie${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "If Maysie doesn't start, check:"
    echo -e "  1. API keys are configured in debug mode"
    echo -e "  2. Virtual environment: ${GREEN}/opt/maysie/venv${NC}"
    echo -e "  3. Service logs: ${GREEN}journalctl -u maysie.service${NC}"
    echo -e "  4. DBus session: ${GREEN}echo \$DBUS_SESSION_BUS_ADDRESS${NC}"
    echo ""
    echo -e "${YELLOW}For more information, visit:${NC}"
    echo -e "${GREEN}https://github.com/Manjil740/maysie${NC}"
    echo ""
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up temporary files...${NC}"
    rm -rf /tmp/pip-* 2>/dev/null || true
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Main installation
main() {
    echo -e "${YELLOW}Starting Maysie installation...${NC}"
    echo ""
    
    detect_distro
    echo ""
    
    verify_python
    echo ""
    
    install_dependencies
    echo ""
    
    create_directories
    echo ""
    
    copy_files
    echo ""
    
    install_python_deps
    echo ""
    
    setup_python_path
    echo ""
    
    setup_service
    echo ""
    
    create_config
    echo ""
    
    setup_log_rotation
    echo ""
    
    test_installation
    echo ""
    
    if start_service; then
        show_completion
    else
        echo -e "${YELLOW}⚠ Service startup had issues${NC}"
        echo -e "${YELLOW}  Please check the logs and run: sudo systemctl status maysie${NC}"
        show_completion
    fi
    
    cleanup
}

# Run installation
main