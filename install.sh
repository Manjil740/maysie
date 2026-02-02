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
                python3-cairo \
                python3-cairo-dev \
                libcairo2-dev \
                libgirepository1.0-dev \
                gobject-introspection \
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
                ca-certificates
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
                ca-certificates
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
                base-devel \
                curl \
                wget \
                git \
                xclip \
                dbus \
                dbus-glib \
                sudo \
                systemd \
                ca-certificates
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
                python3-cairo \
                cairo-devel \
                gobject-introspection-devel \
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
                ca-certificates
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO${NC}"
            echo -e "${YELLOW}Trying to install generic dependencies...${NC}"
            # Try generic installation
            if command -v apt-get &> /dev/null; then
                apt-get update
                apt-get install -y python3 python3-pip python3-venv python3-dev python3-gi
            elif command -v dnf &> /dev/null; then
                dnf install -y python3 python3-pip python3-devel python3-gobject
            elif command -v yum &> /dev/null; then
                yum install -y python3 python3-pip python3-devel python3-gobject
            elif command -v pacman &> /dev/null; then
                pacman -Sy --noconfirm python python-pip python-virtualenv python-gobject
            elif command -v zypper &> /dev/null; then
                zypper install -y python3 python3-pip python3-venv python3-devel python3-gobject
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

# Install Python dependencies
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
    
    # Install dependencies from requirements.txt
    if [ -f "/opt/maysie/requirements.txt" ]; then
        echo -e "${YELLOW}Installing from requirements.txt...${NC}"
        pip install -r /opt/maysie/requirements.txt
    else
        echo -e "${YELLOW}requirements.txt not found, installing individual packages...${NC}"
        pip install \
            aiohttp==3.9.0 \
            asyncio==3.4.3 \
            cryptography==41.0.0 \
            PyYAML==6.0.1 \
            pynput==1.7.6 \
            psutil==5.9.0 \
            PyGObject==3.42.0 \
            pycairo==1.23.0 \
            Flask==3.0.0 \
            Flask-CORS==4.0.0 \
            Werkzeug==3.0.0 \
            openai==1.3.0 \
            google-generativeai==0.3.0 \
            anthropic==0.7.0 \
            python-daemon==3.0.1 \
            dbus-python==1.3.2 \
            python-dotenv==1.0.0 \
            requests==2.31.0 \
            jsonschema==4.20.0 \
            python-dateutil==2.8.2 \
            python-socketio==5.9.0 \
            eventlet==0.33.3 \
            colorama==0.4.6
    fi
    
    # Verify critical packages
    echo -e "${YELLOW}Verifying critical packages...${NC}"
    if python3 -c "import gi; import dbus; import pynput; print('✓ Critical imports successful')" 2>/dev/null; then
        echo -e "${GREEN}✓ Python dependencies verified${NC}"
    else
        echo -e "${YELLOW}⚠ Some packages may need manual installation${NC}"
    fi
    
    deactivate
    
    echo -e "${GREEN}✓ Python dependencies installed${NC}"
}

# Copy files
copy_files() {
    echo -e "${YELLOW}Copying application files...${NC}"
    
    # Get the source directory (where install.sh is located)
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Check if we're running from the source directory
    if [ ! -f "$SCRIPT_DIR/maysie/__init__.py" ]; then
        echo -e "${RED}Error: Cannot find Maysie source files${NC}"
        echo -e "${YELLOW}Please run this script from the Maysie directory${NC}"
        exit 1
    fi
    
    # Copy the entire maysie directory structure
    echo -e "${YELLOW}Copying source files...${NC}"
    cp -r "$SCRIPT_DIR/maysie" /opt/maysie/
    cp "$SCRIPT_DIR/requirements.txt" /opt/maysie/ 2>/dev/null || true
    
    # Copy service file
    if [ -f "$SCRIPT_DIR/maysie.service" ]; then
        cp "$SCRIPT_DIR/maysie.service" /opt/maysie/
    fi
    
    # Make scripts executable
    chmod +x /opt/maysie/maysie/*.py 2>/dev/null || true
    
    # Set permissions
    chown -R $ACTUAL_USER:$ACTUAL_USER /opt/maysie
    
    echo -e "${GREEN}✓ Files copied${NC}"
}

# Setup Python path
setup_python_path() {
    echo -e "${YELLOW}Setting up Python path...${NC}"
    
    # Get Python version
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d' ' -f2 | cut -d. -f1,2)
    PYTHON_PATH="/usr/local/lib/python$PYTHON_VERSION/dist-packages"
    
    # Create directory if it doesn't exist
    mkdir -p "$PYTHON_PATH"
    
    # Create .pth file to add /opt/maysie to Python path
    echo "/opt/maysie" > "$PYTHON_PATH/maysie.pth"
    
    echo -e "${GREEN}✓ Python path configured${NC}"
}

# Setup systemd service
setup_service() {
    echo -e "${YELLOW}Setting up systemd service...${NC}"
    
    SERVICE_FILE="/opt/maysie/maysie.service"
    if [ ! -f "$SERVICE_FILE" ]; then
        # Create service file
        cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Maysie AI Assistant
After=network.target dbus.service
Wants=network.target dbus.service

[Service]
Type=simple
User=$ACTUAL_USER
Group=$ACTUAL_USER
WorkingDirectory=/opt/maysie
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
ProtectSystem=strict
PrivateTmp=true
PrivateDevices=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
ReadWritePaths=/var/log/maysie /etc/maysie /tmp/maysie

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Copy service file to systemd
    cp "$SERVICE_FILE" /etc/systemd/system/maysie.service
    
    # Replace placeholders in service file
    sed -i "s/%u/$ACTUAL_USER/g; s/%U/$(id -u $ACTUAL_USER)/g" /etc/systemd/system/maysie.service
    
    # Set permissions
    chmod 644 /etc/systemd/system/maysie.service
    
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
    postrotate
        systemctl reload maysie.service > /dev/null 2>&1 || true
    endscript
}
EOF
    
    echo -e "${GREEN}✓ Log rotation configured${NC}"
}

# Enable and start service
start_service() {
    echo -e "${YELLOW}Starting Maysie service...${NC}"
    
    # Enable service
    systemctl enable maysie.service
    
    # Start service
    if systemctl start maysie.service; then
        echo -e "${GREEN}✓ Maysie service started successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Service failed to start, checking status...${NC}"
        systemctl status maysie.service --no-pager
        return 1
    fi
    
    # Check status
    sleep 3
    if systemctl is-active --quiet maysie.service; then
        echo -e "${GREEN}✓ Maysie is running${NC}"
    else
        echo -e "${YELLOW}⚠ Service is not active${NC}"
        echo -e "${YELLOW}  Check logs: journalctl -u maysie.service${NC}"
    fi
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
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "If Maysie doesn't start, check:"
    echo -e "  1. API keys are configured in debug mode"
    echo -e "  2. Virtual environment is set up: /opt/maysie/venv"
    echo -e "  3. Dependencies are installed: check /opt/maysie/requirements.txt"
    echo ""
    echo -e "${YELLOW}For more information, visit:${NC}"
    echo -e "${GREEN}https://github.com/Manjil740/maysie${NC}"
    echo ""
}

# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    # Add any cleanup tasks here
    echo -e "${GREEN}✓ Cleanup complete${NC}"
}

# Error handling
handle_error() {
    echo -e "${RED}================================================${NC}"
    echo -e "${RED}  Installation Failed!${NC}"
    echo -e "${RED}================================================${NC}"
    echo ""
    echo -e "${YELLOW}Error occurred at:${NC} $1"
    echo -e "${YELLOW}Check the logs above for details.${NC}"
    echo ""
    echo -e "${YELLOW}Troubleshooting tips:${NC}"
    echo -e "1. Ensure you have internet connectivity"
    echo -e "2. Check if you have sufficient disk space"
    echo -e "3. Verify your package manager is working"
    echo -e "4. Run with debug: ${GREEN}bash -x install.sh${NC}"
    echo ""
    exit 1
}

# Main installation
main() {
    trap 'handle_error $LINENO' ERR
    
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
    
    start_service
    echo ""
    
    show_completion
    
    # Cleanup on success
    cleanup
}

# Run installation
main