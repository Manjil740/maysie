"""
Secure sudo password handling with caching
Manages privilege escalation for system commands.
"""

import os
import time
import subprocess
import threading
from typing import Optional, Tuple
from dataclasses import dataclass
from datetime import datetime, timedelta

from maysie.utils.logger import get_logger
from maysie.config import get_config

logger = get_logger(__name__)


@dataclass
class CachedCredential:
    """Cached sudo credential"""
    password: str
    expires_at: datetime
    
    def is_valid(self) -> bool:
        """Check if credential is still valid"""
        return datetime.now() < self.expires_at


class SudoHandler:
    """Manages sudo authentication and credential caching"""
    
    def __init__(self):
        """Initialize sudo handler"""
        self.config = get_config()
        self._cache: Optional[CachedCredential] = None
        self._lock = threading.Lock()
        self._cleanup_thread = None
        self._start_cleanup_thread()
    
    def set_password(self, password: str, timeout: Optional[int] = None):
        """
        Cache sudo password.
        
        Args:
            password: Sudo password
            timeout: Cache timeout in seconds (default from config)
        """
        with self._lock:
            timeout_seconds = timeout or self.config.sudo.cache_timeout
            expires_at = datetime.now() + timedelta(seconds=timeout_seconds)
            
            # Validate password immediately
            if not self._validate_password(password):
                raise ValueError("Invalid sudo password")
            
            self._cache = CachedCredential(password, expires_at)
            logger.info(f"Sudo password cached for {timeout_seconds} seconds")
    
    def get_password(self) -> Optional[str]:
        """
        Get cached password if still valid.
        
        Returns:
            Cached password or None if expired/not set
        """
        with self._lock:
            if self._cache and self._cache.is_valid():
                return self._cache.password
            return None
    
    def clear_cache(self):
        """Clear cached credentials immediately"""
        with self._lock:
            if self._cache:
                logger.info("Sudo cache cleared")
            self._cache = None
    
    def is_cached(self) -> bool:
        """Check if valid password is cached"""
        return self.get_password() is not None
    
    def run_command(self, command: str, password: Optional[str] = None) -> Tuple[int, str, str]:
        """
        Run command with sudo privileges.
        
        Args:
            command: Command to execute
            password: Optional password (uses cache if not provided)
            
        Returns:
            Tuple of (return_code, stdout, stderr)
        """
        sudo_password = password or self.get_password()
        
        if sudo_password is None:
            raise ValueError("No sudo password available. Use 'sudo code:<password>' first.")
        
        # Security check for dangerous commands
        if self._is_dangerous_command(command):
            if self.config.sudo.require_confirmation:
                raise ValueError(
                    f"Dangerous command blocked: {command}\n"
                    "This command requires explicit user confirmation."
                )
        
        try:
            # Use sudo -S to read password from stdin
            full_command = f"sudo -S {command}"
            
            process = subprocess.Popen(
                full_command,
                shell=True,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            # Send password to sudo
            stdout, stderr = process.communicate(input=f"{sudo_password}\n", timeout=30)
            
            # Filter out sudo password prompt from stderr
            stderr_lines = [
                line for line in stderr.split('\n')
                if not line.startswith('[sudo]') and line.strip()
            ]
            stderr_cleaned = '\n'.join(stderr_lines)
            
            logger.info(f"Sudo command executed: {command[:50]}... (rc={process.returncode})")
            return process.returncode, stdout, stderr_cleaned
            
        except subprocess.TimeoutExpired:
            process.kill()
            logger.error(f"Sudo command timeout: {command}")
            return -1, "", "Command execution timeout"
        except Exception as e:
            logger.error(f"Sudo command failed: {e}")
            return -1, "", str(e)
    
    def _validate_password(self, password: str) -> bool:
        """
        Validate sudo password by running a harmless command.
        
        Args:
            password: Password to validate
            
        Returns:
            True if password is valid
        """
        try:
            process = subprocess.Popen(
                "sudo -S -v",  # -v validates credentials without running a command
                shell=True,
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            _, stderr = process.communicate(input=f"{password}\n", timeout=5)
            
            # Success if no error and return code is 0
            return process.returncode == 0
            
        except Exception as e:
            logger.error(f"Password validation failed: {e}")
            return False
    
    def _is_dangerous_command(self, command: str) -> bool:
        """
        Check if command is potentially dangerous.
        
        Args:
            command: Command to check
            
        Returns:
            True if command matches dangerous patterns
        """
        dangerous = self.config.sudo.dangerous_commands
        command_lower = command.lower().strip()
        
        for pattern in dangerous:
            if pattern.lower() in command_lower:
                return True
        
        # Additional checks
        if 'rm' in command_lower and '-rf' in command_lower and '/' in command_lower:
            # Check if trying to delete root or important paths
            important_paths = ['/', '/usr', '/etc', '/var', '/bin', '/sbin', '/lib']
            for path in important_paths:
                if f" {path}" in command_lower or f"/{path}" in command_lower:
                    return True
        
        return False
    
    def _start_cleanup_thread(self):
        """Start background thread to clean expired credentials"""
        def cleanup_loop():
            while True:
                time.sleep(60)  # Check every minute
                with self._lock:
                    if self._cache and not self._cache.is_valid():
                        logger.debug("Sudo cache expired, clearing")
                        self._cache = None
        
        self._cleanup_thread = threading.Thread(target=cleanup_loop, daemon=True)
        self._cleanup_thread.start()


# Global instance
_global_sudo_handler: Optional[SudoHandler] = None


def get_sudo_handler() -> SudoHandler:
    """Get global sudo handler instance"""
    global _global_sudo_handler
    if _global_sudo_handler is None:
        _global_sudo_handler = SudoHandler()
    return _global_sudo_handler