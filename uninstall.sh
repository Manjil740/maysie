#!/bin/bash
# Maysie Uninstallation Script

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}================================================${NC}"
echo -e "${RED}  Maysie AI Assistant - Uninstallation${NC}"
echo -e "${RED}================================================${NC}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Confirmation
read -p "Are you sure you want to uninstall Maysie? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Uninstallation cancelled."
    exit 0
fi

# Ask about config backup
echo ""
read -p "Do you want to backup configuration files? (yes/no): " BACKUP
if [ "$BACKUP" == "yes" ]; then
    BACKUP_DIR="$HOME/maysie-backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    if [ -d /etc/maysie ]; then
        cp -r /etc/maysie "$BACKUP_DIR/"
        echo -e "${GREEN}✓ Configuration backed up to: $BACKUP_DIR${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}Stopping and removing service...${NC}"

# Stop service
if systemctl is-active --quiet maysie.service; then
    systemctl stop maysie.service
    echo -e "${GREEN}✓ Service stopped${NC}"
fi

# Disable service
if systemctl is-enabled --quiet maysie.service 2>/dev/null; then
    systemctl disable maysie.service
    echo -e "${GREEN}✓ Service disabled${NC}"
fi

# Remove service file
if [ -f /etc/systemd/system/maysie.service ]; then
    rm /etc/systemd/system/maysie.service
    systemctl daemon-reload
    echo -e "${GREEN}✓ Service file removed${NC}"
fi

echo ""
echo -e "${YELLOW}Removing files and directories...${NC}"

# Remove application files
if [ -d /opt/maysie ]; then
    rm -rf /opt/maysie
    echo -e "${GREEN}✓ Application files removed${NC}"
fi

# Remove configuration
if [ -d /etc/maysie ]; then
    rm -rf /etc/maysie
    echo -e "${GREEN}✓ Configuration removed${NC}"
fi

# Remove logs
if [ -d /var/log/maysie ]; then
    rm -rf /var/log/maysie
    echo -e "${GREEN}✓ Logs removed${NC}"
fi

# Remove data directory
if [ -d /usr/share/maysie ]; then
    rm -rf /usr/share/maysie
    echo -e "${GREEN}✓ Data directory removed${NC}"
fi

# Remove Python path file
rm -f /usr/local/lib/python*/dist-packages/maysie.pth 2>/dev/null || true

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Uninstallation Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""

if [ "$BACKUP" == "yes" ]; then
    echo -e "Configuration backup saved to: ${GREEN}$BACKUP_DIR${NC}"
    echo ""
fi

echo -e "Maysie has been completely removed from your system."
echo -e "Python dependencies were not removed as they may be used by other programs."
echo ""