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
            apt-get update
            apt-get install -y \
                python3 \
                python3-pip \
                python3-gi \
                python3-gi-cairo \
                gir1.2-gtk-3.0 \
                python3-cairo \
                python3-venv \
                libcairo2-dev \
                libgirepository1.0-dev \
                pkg-config
            ;;
        fedora)
            dnf install -y \
                python3 \
                python3-pip \
                python3-gobject \
                gtk3 \
                cairo \
                cairo-gobject-devel \
                gobject-introspection-devel \
                python3-cairo-devel
            ;;
        arch|manjaro)
            pacman -Sy --noconfirm \
                python \
                python-pip \
                python-gobject \
                gtk3 \
                cairo \
                gobject-introspection
            ;;
        opensuse*|sles)
            zypper install -y \
                python3 \
                python3-pip \
                python3-gobject \
                typelib-1_0-Gtk-3_0 \
                python3-cairo \
                cairo-devel \
                gobject-introspection-devel
            ;;
        *)
            echo -e "${RED}Unsupported distribution: $DISTRO${NC}"
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}✓ System dependencies installed${NC}"
}

# Create directories
create_directories() {
    echo -e "${YELLOW}Creating directories...${NC}"
    
    mkdir -p /opt/maysie
    mkdir -p /etc/maysie
    mkdir -p /var/log/maysie
    mkdir -p /usr/share/maysie
    
    # Set permissions
    chown -R root:root /opt/maysie
    chown -R $ACTUAL_USER:$ACTUAL_USER /var/log/maysie
    chown -R root:root /etc/maysie
    chmod 755 /opt/maysie
    chmod 755 /etc/maysie
    chmod 755 /var/log/maysie
    
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Install Python dependencies
install_python_deps() {
    echo -e "${YELLOW}Installing Python dependencies...${NC}"
    
    # Upgrade pip
    python3 -m pip install --upgrade pip
    
    # Install requirements
    python3 -m pip install -r requirements.txt
    
    echo -e "${GREEN}✓ Python dependencies installed${NC}"
}

# Copy files
copy_files() {
    echo -e "${YELLOW}Copying application files...${NC}"
    
    # Copy Python package
    cp -r maysie /opt/maysie/
    
    # Create symlink for easy execution
    ln -sf /opt/maysie/maysie /usr/local/lib/python3*/dist-packages/maysie 2>/dev/null || true
    
    # Make maysie module importable
    echo "/opt/maysie" > /usr/local/lib/python$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1,2)/dist-packages/maysie.pth
    
    echo -e "${GREEN}✓ Files copied${NC}"
}

# Setup systemd service
setup_service() {
    echo -e "${YELLOW}Setting up systemd service...${NC}"
    
    # Replace %u placeholder with actual user
    sed "s/%u/$ACTUAL_USER/g; s/%U/$(id -u $ACTUAL_USER)/g" maysie.service > /etc/systemd/system/maysie.service
    
    # Set permissions
    chmod 644 /etc/systemd/system/maysie.service
    
    # Reload systemd
    systemctl daemon-reload
    
    echo -e "${GREEN}✓ Systemd service configured${NC}"
}

# Create default config
create_config() {
    echo -e "${YELLOW}Creating default configuration...${NC}"
    
    if [ ! -f /etc/maysie/config.yaml ]; then
        # Config will be created by first run
        echo -e "${GREEN}✓ Configuration will be created on first run${NC}"
    else
        echo -e "${GREEN}✓ Existing configuration preserved${NC}"
    fi
}

# Enable and start service
start_service() {
    echo -e "${YELLOW}Starting Maysie service...${NC}"
    
    # Enable service
    systemctl enable maysie.service
    
    # Start service
    systemctl start maysie.service
    
    # Check status
    sleep 2
    if systemctl is-active --quiet maysie.service; then
        echo -e "${GREEN}✓ Maysie service started successfully${NC}"
    else
        echo -e "${YELLOW}⚠ Service started but may need configuration${NC}"
        echo -e "${YELLOW}  Check status: sudo systemctl status maysie${NC}"
    fi
}

# Main installation
main() {
    detect_distro
    echo ""
    
    install_dependencies
    echo ""
    
    create_directories
    echo ""
    
    install_python_deps
    echo ""
    
    copy_files
    echo ""
    
    setup_service
    echo ""
    
    create_config
    echo ""
    
    start_service
    echo ""
    
    echo -e "${GREEN}================================================${NC}"
    echo -e "${GREEN}  Installation Complete!${NC}"
    echo -e "${GREEN}================================================${NC}"
    echo ""
    echo -e "Next steps:"
    echo -e "1. Press ${GREEN}Super+Alt+A${NC} to open Maysie"
    echo -e "2. Type: ${GREEN}enter debug mode <your_password>${NC}"
    echo -e "3. Configure AI API keys in the web interface"
    echo ""
    echo -e "Useful commands:"
    echo -e "  ${GREEN}sudo systemctl status maysie${NC}  - Check service status"
    echo -e "  ${GREEN}sudo systemctl restart maysie${NC} - Restart service"
    echo -e "  ${GREEN}tail -f /var/log/maysie/maysie.log${NC} - View logs"
    echo ""
    echo -e "Documentation: ${GREEN}https://github.com/yourusername/maysie${NC}"
    echo ""
}

# Run installation
main