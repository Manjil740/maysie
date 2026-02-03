sudo tee /opt/maysie/maysie/utils/security.py > /dev/null << 'EOF'
"""
Security utilities for Maysie
Handles encryption, credential management, and secure operations.
"""

import os
import hashlib
import secrets
from pathlib import Path
from typing import Optional, Dict
from cryptography.fernet import Fernet
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.kdf.pbkdf2 import PBKDF2HMAC
from cryptography.hazmat.backends import default_backend

from maysie.utils.logger import get_logger

logger = get_logger(__name__)


class SecurityManager:
    """Manages encryption and security operations"""
    
    def __init__(self, key_file: Optional[Path] = None):
        """
        Initialize security manager.
        
        Args:
            key_file: Path to encryption key file
        """
        self.key_file = key_file or Path('/etc/maysie/.key')
        self._cipher = None
        self._initialize_cipher()
    
    def _initialize_cipher(self):
        """Initialize or load encryption cipher"""
        try:
            if self.key_file.exists():
                key = self.key_file.read_bytes()
            else:
                # Generate new key
                key = Fernet.generate_key()
                self._save_key(key)
            
            self._cipher = Fernet(key)
            logger.info("Security manager initialized")
        except Exception as e:
            logger.error(f"Failed to initialize cipher: {e}")
            # Fallback: use temporary key (in-memory only)
            self._cipher = Fernet(Fernet.generate_key())
            logger.warning("Using temporary encryption key (not persistent)")
    
    def _save_key(self, key: bytes):
        """Save encryption key with proper permissions"""
        try:
            self.key_file.parent.mkdir(parents=True, exist_ok=True)
            self.key_file.write_bytes(key)
            os.chmod(self.key_file, 0o600)  # Read/write for owner only
            logger.info(f"Encryption key saved to {self.key_file}")
        except (PermissionError, OSError) as e:
            logger.error(f"Cannot save encryption key: {e}")
    
    def encrypt(self, data: str) -> str:
        """
        Encrypt string data.
        
        Args:
            data: Plain text to encrypt
            
        Returns:
            Encrypted data as base64 string
        """
        try:
            encrypted = self._cipher.encrypt(data.encode('utf-8'))
            return encrypted.decode('utf-8')
        except Exception as e:
            logger.error(f"Encryption failed: {e}")
            raise
    
    def decrypt(self, encrypted_data: str) -> str:
        """
        Decrypt string data.
        
        Args:
            encrypted_data: Encrypted base64 string
            
        Returns:
            Decrypted plain text
        """
        try:
            decrypted = self._cipher.decrypt(encrypted_data.encode('utf-8'))
            return decrypted.decode('utf-8')
        except Exception as e:
            logger.error(f"Decryption failed: {e}")
            raise
    
    @staticmethod
    def hash_password(password: str, salt: Optional[bytes] = None) -> tuple[str, str]:
        """
        Hash password using PBKDF2.
        
        Args:
            password: Plain text password
            salt: Optional salt (generated if not provided)
            
        Returns:
            Tuple of (hashed_password, salt) as hex strings
        """
        if salt is None:
            salt = secrets.token_bytes(32)
        
        kdf = PBKDF2HMAC(
            algorithm=hashes.SHA256(),
            length=32,
            salt=salt,
            iterations=100000,
            backend=default_backend()
        )
        
        key = kdf.derive(password.encode('utf-8'))
        return key.hex(), salt.hex()
    
    @staticmethod
    def verify_password(password: str, hashed: str, salt: str) -> bool:
        """
        Verify password against hash.
        
        Args:
            password: Plain text password to verify
            hashed: Hashed password (hex string)
            salt: Salt used for hashing (hex string)
            
        Returns:
            True if password matches
        """
        try:
            computed_hash, _ = SecurityManager.hash_password(
                password, 
                bytes.fromhex(salt)
            )
            return secrets.compare_digest(computed_hash, hashed)
        except Exception as e:
            logger.error(f"Password verification failed: {e}")
            return False
    
    @staticmethod
    def generate_token(length: int = 32) -> str:
        """Generate cryptographically secure random token"""
        return secrets.token_urlsafe(length)


class CredentialStore:
    """Secure storage for API keys and credentials"""
    
    def __init__(self, storage_file: Path, security_mgr: SecurityManager):
        """
        Initialize credential store.
        
        Args:
            storage_file: Path to encrypted storage file
            security_mgr: SecurityManager instance for encryption
        """
        self.storage_file = storage_file
        self.security_mgr = security_mgr
        self._credentials: Dict[str, str] = {}
        self._load()
    
    def _load(self):
        """Load and decrypt credentials from file"""
        try:
            if self.storage_file.exists():
                encrypted_data = self.storage_file.read_text()
                if encrypted_data.strip():
                    decrypted = self.security_mgr.decrypt(encrypted_data)
                    # Parse key=value format
                    for line in decrypted.split('\n'):
                        if '=' in line:
                            key, value = line.split('=', 1)
                            self._credentials[key.strip()] = value.strip()
                logger.info(f"Loaded {len(self._credentials)} credentials")
        except Exception as e:
            logger.error(f"Failed to load credentials: {e}")
            self._credentials = {}
    
    def _save(self):
        """Encrypt and save credentials to file"""
        try:
            # Convert to key=value format
            data = '\n'.join(f"{k}={v}" for k, v in self._credentials.items())
            encrypted = self.security_mgr.encrypt(data)
            
            self.storage_file.parent.mkdir(parents=True, exist_ok=True)
            self.storage_file.write_text(encrypted)
            os.chmod(self.storage_file, 0o600)
            logger.info(f"Saved {len(self._credentials)} credentials")
        except Exception as e:
            logger.error(f"Failed to save credentials: {e}")
    
    def set(self, key: str, value: str):
        """Store a credential"""
        self._credentials[key] = value
        self._save()
    
    def get(self, key: str, default: Optional[str] = None) -> Optional[str]:
        """Retrieve a credential"""
        return self._credentials.get(key, default)
    
    def delete(self, key: str):
        """Delete a credential"""
        if key in self._credentials:
            del self._credentials[key]
            self._save()
    
    def list_keys(self) -> list[str]:
        """List all credential keys (not values)"""
        return list(self._credentials.keys())


# Module-level convenience functions
_global_security_mgr: Optional[SecurityManager] = None


def get_security_manager() -> SecurityManager:
    """Get global security manager instance"""
    global _global_security_mgr
    if _global_security_mgr is None:
        _global_security_mgr = SecurityManager()
    return _global_security_mgr


def encrypt_data(data: str) -> str:
    """Encrypt data using global security manager"""
    return get_security_manager().encrypt(data)


def decrypt_data(encrypted_data: str) -> str:
    """Decrypt data using global security manager"""
    return get_security_manager().decrypt(encrypted_data)
EOF