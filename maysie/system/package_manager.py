"""
Multi-distribution package manager
Auto-detects and uses the appropriate package manager for the system.
"""

import os
import re
import subprocess
from typing import List, Optional, Tuple
from enum import Enum

from maysie.utils.logger import get_logger
from maysie.system.sudo_handler import get_sudo_handler

logger = get_logger(__name__)


class PackageManager(Enum):
    """Supported package managers"""
    APT = "apt"          # Debian, Ubuntu
    DNF = "dnf"          # Fedora, RHEL 8+
    YUM = "yum"          # RHEL 7, CentOS 7
    PACMAN = "pacman"    # Arch, Manjaro
    ZYPPER = "zypper"    # openSUSE
    UNKNOWN = "unknown"


class SystemPackageManager:
    """Manages package installation across different Linux distributions"""
    
    def __init__(self):
        """Initialize package manager"""
        self.pm_type = self._detect_package_manager()
        self.sudo_handler = get_sudo_handler()
        logger.info(f"Detected package manager: {self.pm_type.value}")
    
    def _detect_package_manager(self) -> PackageManager:
        """
        Auto-detect system package manager.
        
        Returns:
            PackageManager enum value
        """
        # Check for package manager binaries
        managers = [
            (PackageManager.APT, "apt"),
            (PackageManager.DNF, "dnf"),
            (PackageManager.YUM, "yum"),
            (PackageManager.PACMAN, "pacman"),
            (PackageManager.ZYPPER, "zypper"),
        ]
        
        for pm, binary in managers:
            if self._command_exists(binary):
                return pm
        
        # Fallback: check /etc/os-release
        try:
            with open('/etc/os-release', 'r') as f:
                content = f.read().lower()
                if 'ubuntu' in content or 'debian' in content:
                    return PackageManager.APT
                elif 'fedora' in content:
                    return PackageManager.DNF
                elif 'rhel' in content or 'centos' in content:
                    if self._command_exists('dnf'):
                        return PackageManager.DNF
                    return PackageManager.YUM
                elif 'arch' in content or 'manjaro' in content:
                    return PackageManager.PACMAN
                elif 'suse' in content or 'opensuse' in content:
                    return PackageManager.ZYPPER
        except Exception as e:
            logger.error(f"Failed to detect package manager from os-release: {e}")
        
        return PackageManager.UNKNOWN
    
    @staticmethod
    def _command_exists(command: str) -> bool:
        """Check if command exists in PATH"""
        return subprocess.run(
            ['which', command],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        ).returncode == 0
    
    def install(self, packages: List[str]) -> Tuple[bool, str]:
        """
        Install packages.
        
        Args:
            packages: List of package names
            
        Returns:
            Tuple of (success, message)
        """
        if not packages:
            return False, "No packages specified"
        
        package_str = ' '.join(packages)
        
        commands = {
            PackageManager.APT: f"apt install -y {package_str}",
            PackageManager.DNF: f"dnf install -y {package_str}",
            PackageManager.YUM: f"yum install -y {package_str}",
            PackageManager.PACMAN: f"pacman -S --noconfirm {package_str}",
            PackageManager.ZYPPER: f"zypper install -y {package_str}",
        }
        
        command = commands.get(self.pm_type)
        if not command:
            return False, f"Unsupported package manager: {self.pm_type.value}"
        
        try:
            # Update package lists first for APT/DNF
            if self.pm_type in [PackageManager.APT, PackageManager.DNF]:
                self._update_cache()
            
            rc, stdout, stderr = self.sudo_handler.run_command(command)
            
            if rc == 0:
                return True, f"Successfully installed: {package_str}"
            else:
                return False, f"Installation failed: {stderr or stdout}"
                
        except Exception as e:
            logger.error(f"Package installation error: {e}")
            return False, str(e)
    
    def uninstall(self, packages: List[str], purge: bool = False) -> Tuple[bool, str]:
        """
        Uninstall packages.
        
        Args:
            packages: List of package names
            purge: Remove configuration files too (APT only)
            
        Returns:
            Tuple of (success, message)
        """
        if not packages:
            return False, "No packages specified"
        
        package_str = ' '.join(packages)
        
        commands = {
            PackageManager.APT: f"apt {'purge' if purge else 'remove'} -y {package_str}",
            PackageManager.DNF: f"dnf remove -y {package_str}",
            PackageManager.YUM: f"yum remove -y {package_str}",
            PackageManager.PACMAN: f"pacman -R --noconfirm {package_str}",
            PackageManager.ZYPPER: f"zypper remove -y {package_str}",
        }
        
        command = commands.get(self.pm_type)
        if not command:
            return False, f"Unsupported package manager: {self.pm_type.value}"
        
        try:
            rc, stdout, stderr = self.sudo_handler.run_command(command)
            
            if rc == 0:
                return True, f"Successfully uninstalled: {package_str}"
            else:
                return False, f"Uninstallation failed: {stderr or stdout}"
                
        except Exception as e:
            logger.error(f"Package uninstallation error: {e}")
            return False, str(e)
    
    def update(self) -> Tuple[bool, str]:
        """
        Update all packages.
        
        Returns:
            Tuple of (success, message)
        """
        commands = {
            PackageManager.APT: "apt update && apt upgrade -y",
            PackageManager.DNF: "dnf upgrade -y",
            PackageManager.YUM: "yum update -y",
            PackageManager.PACMAN: "pacman -Syu --noconfirm",
            PackageManager.ZYPPER: "zypper update -y",
        }
        
        command = commands.get(self.pm_type)
        if not command:
            return False, f"Unsupported package manager: {self.pm_type.value}"
        
        try:
            rc, stdout, stderr = self.sudo_handler.run_command(command)
            
            if rc == 0:
                return True, "System updated successfully"
            else:
                return False, f"Update failed: {stderr or stdout}"
                
        except Exception as e:
            logger.error(f"System update error: {e}")
            return False, str(e)
    
    def search(self, query: str) -> Tuple[bool, str]:
        """
        Search for packages.
        
        Args:
            query: Search query
            
        Returns:
            Tuple of (success, results)
        """
        commands = {
            PackageManager.APT: f"apt search {query}",
            PackageManager.DNF: f"dnf search {query}",
            PackageManager.YUM: f"yum search {query}",
            PackageManager.PACMAN: f"pacman -Ss {query}",
            PackageManager.ZYPPER: f"zypper search {query}",
        }
        
        command = commands.get(self.pm_type)
        if not command:
            return False, f"Unsupported package manager: {self.pm_type.value}"
        
        try:
            # Search doesn't need sudo
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0:
                # Parse and format output
                output = result.stdout[:1000]  # Limit output
                return True, output
            else:
                return False, "Search failed"
                
        except Exception as e:
            logger.error(f"Package search error: {e}")
            return False, str(e)
    
    def _update_cache(self):
        """Update package cache (APT/DNF)"""
        try:
            if self.pm_type == PackageManager.APT:
                self.sudo_handler.run_command("apt update")
            elif self.pm_type == PackageManager.DNF:
                self.sudo_handler.run_command("dnf check-update")
        except Exception as e:
            logger.warning(f"Cache update failed: {e}")
    
    def is_installed(self, package: str) -> bool:
        """
        Check if package is installed.
        
        Args:
            package: Package name
            
        Returns:
            True if installed
        """
        commands = {
            PackageManager.APT: f"dpkg -l {package}",
            PackageManager.DNF: f"dnf list installed {package}",
            PackageManager.YUM: f"yum list installed {package}",
            PackageManager.PACMAN: f"pacman -Q {package}",
            PackageManager.ZYPPER: f"zypper search -i {package}",
        }
        
        command = commands.get(self.pm_type)
        if not command:
            return False
        
        try:
            result = subprocess.run(
                command,
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception:
            return False


# Global instance
_global_package_manager: Optional[SystemPackageManager] = None


def get_package_manager() -> SystemPackageManager:
    """Get global package manager instance"""
    global _global_package_manager
    if _global_package_manager is None:
        _global_package_manager = SystemPackageManager()
    return _global_package_manager