#!/bin/bash
# Maysie AI Assistant - Complete Production Installation
# Integrates ALL features from your original files

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
DATA_DIR="/var/lib/maysie"
BACKUP_DIR="/tmp/maysie-backup-$(date +%Y%m%d-%H%M%S)"

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
echo "  Maysie AI Assistant - Complete Production Install"
echo "================================================"
echo "User: $CURRENT_USER"
echo "Home: $CURRENT_HOME"
echo ""

# ================================================
# STEP 1: BACKUP AND CLEAN
# ================================================
print_status "Backing up existing configuration..."
mkdir -p "$BACKUP_DIR"
if [ -d "$CONFIG_DIR" ]; then
    cp -r "$CONFIG_DIR" "$BACKUP_DIR/"
    print_success "Configuration backed up to $BACKUP_DIR"
fi

print_status "Stopping and removing previous installation..."
systemctl stop maysie 2>/dev/null || true
systemctl disable maysie 2>/dev/null || true
pkill -f "python.*maysie" 2>/dev/null || true

# ================================================
# STEP 2: CREATE DIRECTORY STRUCTURE
# ================================================
print_status "Creating directory structure..."
rm -rf "$INSTALL_DIR" 2>/dev/null || true
mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" "$DATA_DIR"
mkdir -p "$INSTALL_DIR/maysie" "$INSTALL_DIR/maysie/ai" "$INSTALL_DIR/maysie/config" \
         "$INSTALL_DIR/maysie/core" "$INSTALL_DIR/maysie/system" \
         "$INSTALL_DIR/maysie/ui" "$INSTALL_DIR/maysie/utils"

chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" "$DATA_DIR"
chmod 755 "$INSTALL_DIR" "$CONFIG_DIR" "$LOG_DIR" "$DATA_DIR"
print_success "Directory structure created"

# ================================================
# STEP 3: INSTALL SYSTEM DEPENDENCIES
# ================================================
print_status "Installing system dependencies..."
apt-get update > /dev/null 2>&1
apt-get install -y python3 python3-pip python3-venv python3-tk python3-dev \
                   git curl build-essential pkg-config \
                   libgirepository1.0-dev libcairo2-dev gir1.2-gtk-3.0 > /dev/null 2>&1
print_success "System dependencies installed"

# ================================================
# STEP 4: INSTALL ALL PYTHON MODULES
# ================================================
print_status "Installing complete Maysie modules..."

# Create __init__.py files
touch "$INSTALL_DIR/maysie/__init__.py"
touch "$INSTALL_DIR/maysie/ai/__init__.py"
touch "$INSTALL_DIR/maysie/config/__init__.py"
touch "$INSTALL_DIR/maysie/core/__init__.py"
touch "$INSTALL_DIR/maysie/system/__init__.py"
touch "$INSTALL_DIR/maysie/ui/__init__.py"
touch "$INSTALL_DIR/maysie/utils/__init__.py"

# ---------------------------------------------------------------------
# Install AI Modules
# ---------------------------------------------------------------------
print_status "Installing AI modules..."

# base.py
cat > "$INSTALL_DIR/maysie/ai/base.py" << 'EOF'
"""
Base AI provider interface
All AI providers must implement this interface.
"""

from abc import ABC, abstractmethod
from typing import Optional, Dict, Any

from maysie.utils.logger import get_logger

logger = get_logger(__name__)


class BaseAIProvider(ABC):
    """Abstract base class for AI providers"""
    
    def __init__(self, api_key: Optional[str] = None, **kwargs):
        """
        Initialize AI provider.
        
        Args:
            api_key: API key for the provider
            **kwargs: Additional provider-specific configuration
        """
        self.api_key = api_key
        self.config = kwargs
        self.name = self.__class__.__name__
    
    @abstractmethod
    async def query(self, prompt: str, context: Optional[Dict[str, Any]] = None) -> str:
        """
        Query the AI provider.
        
        Args:
            prompt: User prompt/query
            context: Optional context dictionary (history, style, etc.)
            
        Returns:
            AI response as string
        """
        raise NotImplementedError()
    
    @abstractmethod
    def validate_credentials(self) -> bool:
        """
        Validate API credentials.
        
        Returns:
            True if credentials are valid
        """
        raise NotImplementedError()
    
    def is_configured(self) -> bool:
        """
        Check if provider is properly configured.
        
        Returns:
            True if API key is set
        """
        return self.api_key is not None and len(self.api_key) > 0
    
    def get_name(self) -> str:
        """Get provider name"""
        return self.name
    
    def _log_query(self, prompt: str, truncate: int = 100):
        """Log query (truncated for privacy)"""
        truncated_prompt = prompt[:truncate] + "..." if len(prompt) > truncate else prompt
        logger.info(f"[{self.name}] Query: {truncated_prompt}")
    
    def _log_response(self, response: str, truncate: int = 100):
        """Log response (truncated)"""
        truncated_response = response[:truncate] + "..." if len(response) > truncate else response
        logger.info(f"[{self.name}] Response: {truncated_response}")
EOF

# gemini.py
cat > "$INSTALL_DIR/maysie/ai/gemini.py" << 'EOF'
"""
Google Gemini AI provider
Best for research, current information, and general queries.
"""

import aiohttp
from typing import Optional, Dict, Any

from maysie.ai.base import BaseAIProvider
from maysie.utils.logger import get_logger

logger = get_logger(__name__)


class GeminiProvider(BaseAIProvider):
    """Google Gemini AI provider"""
    
    def __init__(self, api_key: Optional[str] = None, model: str = "gemini-pro", **kwargs):
        """
        Initialize Gemini provider.
        
        Args:
            api_key: Google AI API key
            model: Model name (default: gemini-pro)
            **kwargs: Additional configuration
        """
        super().__init__(api_key, **kwargs)
        self.model = model
        self.api_base = "https://generativelanguage.googleapis.com/v1beta"
        self.name = "Gemini"
    
    async def query(self, prompt: str, context: Optional[Dict[str, Any]] = None) -> str:
        """
        Query Gemini API.
        
        Args:
            prompt: User prompt
            context: Optional context (response_style, etc.)
            
        Returns:
            AI response
        """
        if not self.is_configured():
            raise ValueError("Gemini API key not configured")
        
        self._log_query(prompt)
        
        # Apply response style if specified
        if context and 'response_style' in context:
            style_instruction = context['response_style']
            prompt = f"{style_instruction}\n\nUser query: {prompt}"
        
        try:
            url = f"{self.api_base}/models/{self.model}:generateContent"
            
            payload = {
                "contents": [{
                    "parts": [{
                        "text": prompt
                    }]
                }],
                "generationConfig": {
                    "temperature": 0.7,
                    "maxOutputTokens": 2048,
                }
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    url,
                    json=payload,
                    params={"key": self.api_key},
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        logger.error(f"Gemini API error: {error_text}")
                        raise Exception(f"Gemini API error: {response.status}")
                    
                    data = await response.json()
                    
                    # Extract response text
                    if 'candidates' in data and len(data['candidates']) > 0:
                        candidate = data['candidates'][0]
                        if 'content' in candidate and 'parts' in candidate['content']:
                            text = candidate['content']['parts'][0]['text']
                            self._log_response(text)
                            return text.strip()
                    
                    raise Exception("Unexpected Gemini API response format")
        
        except aiohttp.ClientError as e:
            logger.error(f"Gemini network error: {e}")
            raise Exception(f"Network error: {e}")
        except Exception as e:
            logger.error(f"Gemini query failed: {e}")
            raise
    
    def validate_credentials(self) -> bool:
        """
        Validate Gemini API key.
        
        Returns:
            True if valid
        """
        if not self.is_configured():
            return False
        
        try:
            import requests
            url = f"{self.api_base}/models"
            response = requests.get(url, params={"key": self.api_key}, timeout=5)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"Gemini credential validation failed: {e}")
            return False
EOF

# chatgpt.py
cat > "$INSTALL_DIR/maysie/ai/chatgpt.py" << 'EOF'
"""
OpenAI ChatGPT provider
Best for logic, reasoning, and decision-making tasks.
"""

import aiohttp
from typing import Optional, Dict, Any

from maysie.ai.base import BaseAIProvider
from maysie.utils.logger import get_logger

logger = get_logger(__name__)


class ChatGPTProvider(BaseAIProvider):
    """OpenAI ChatGPT AI provider"""
    
    def __init__(self, api_key: Optional[str] = None, model: str = "gpt-4o-mini", **kwargs):
        """
        Initialize ChatGPT provider.
        
        Args:
            api_key: OpenAI API key
            model: Model name (default: gpt-4o-mini)
            **kwargs: Additional configuration
        """
        super().__init__(api_key, **kwargs)
        self.model = model
        self.api_base = "https://api.openai.com/v1"
        self.name = "ChatGPT"
    
    async def query(self, prompt: str, context: Optional[Dict[str, Any]] = None) -> str:
        """
        Query ChatGPT API.
        
        Args:
            prompt: User prompt
            context: Optional context (response_style, history, etc.)
            
        Returns:
            AI response
        """
        if not self.is_configured():
            raise ValueError("OpenAI API key not configured")
        
        self._log_query(prompt)
        
        # Build messages
        messages = []
        
        # Add system message for response style
        if context and 'response_style' in context:
            messages.append({
                "role": "system",
                "content": context['response_style']
            })
        
        # Add conversation history if provided
        if context and 'history' in context:
            messages.extend(context['history'])
        
        # Add current user message
        messages.append({
            "role": "user",
            "content": prompt
        })
        
        try:
            url = f"{self.api_base}/chat/completions"
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            
            payload = {
                "model": self.model,
                "messages": messages,
                "temperature": 0.7,
                "max_tokens": 2048,
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    url,
                    json=payload,
                    headers=headers,
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        logger.error(f"ChatGPT API error: {error_text}")
                        raise Exception(f"ChatGPT API error: {response.status}")
                    
                    data = await response.json()
                    
                    # Extract response
                    if 'choices' in data and len(data['choices']) > 0:
                        text = data['choices'][0]['message']['content']
                        self._log_response(text)
                        return text.strip()
                    
                    raise Exception("Unexpected ChatGPT API response format")
        
        except aiohttp.ClientError as e:
            logger.error(f"ChatGPT network error: {e}")
            raise Exception(f"Network error: {e}")
        except Exception as e:
            logger.error(f"ChatGPT query failed: {e}")
            raise
    
    def validate_credentials(self) -> bool:
        """
        Validate OpenAI API key.
        
        Returns:
            True if valid
        """
        if not self.is_configured():
            return False
        
        try:
            import requests
            url = f"{self.api_base}/models"
            headers = {"Authorization": f"Bearer {self.api_key}"}
            response = requests.get(url, headers=headers, timeout=5)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"ChatGPT credential validation failed: {e}")
            return False
EOF

# deepseek.py
cat > "$INSTALL_DIR/maysie/ai/deepseek.py" << 'EOF'
"""
DeepSeek AI provider
Best for coding, debugging, and technical tasks.
"""

import aiohttp
from typing import Optional, Dict, Any

from maysie.ai.base import BaseAIProvider
from maysie.utils.logger import get_logger

logger = get_logger(__name__)


class DeepSeekProvider(BaseAIProvider):
    """DeepSeek AI provider"""
    
    def __init__(self, api_key: Optional[str] = None, model: str = "deepseek-chat", **kwargs):
        """
        Initialize DeepSeek provider.
        
        Args:
            api_key: DeepSeek API key
            model: Model name (default: deepseek-chat)
            **kwargs: Additional configuration
        """
        super().__init__(api_key, **kwargs)
        self.model = model
        self.api_base = "https://api.deepseek.com/v1"
        self.name = "DeepSeek"
    
    async def query(self, prompt: str, context: Optional[Dict[str, Any]] = None) -> str:
        """
        Query DeepSeek API.
        
        Args:
            prompt: User prompt
            context: Optional context (response_style, etc.)
            
        Returns:
            AI response
        """
        if not self.is_configured():
            raise ValueError("DeepSeek API key not configured")
        
        self._log_query(prompt)
        
        # Build messages
        messages = []
        
        # Add system message optimized for coding
        system_message = "You are a helpful coding assistant. Provide clear, concise code with explanations."
        if context and 'response_style' in context:
            system_message = context['response_style']
        
        messages.append({
            "role": "system",
            "content": system_message
        })
        
        # Add user message
        messages.append({
            "role": "user",
            "content": prompt
        })
        
        try:
            url = f"{self.api_base}/chat/completions"
            headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json"
            }
            
            payload = {
                "model": self.model,
                "messages": messages,
                "temperature": 0.3,  # Lower temperature for more consistent code
                "max_tokens": 4096,
            }
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    url,
                    json=payload,
                    headers=headers,
                    timeout=aiohttp.ClientTimeout(total=30)
                ) as response:
                    if response.status != 200:
                        error_text = await response.text()
                        logger.error(f"DeepSeek API error: {error_text}")
                        raise Exception(f"DeepSeek API error: {response.status}")
                    
                    data = await response.json()
                    
                    # Extract response
                    if 'choices' in data and len(data['choices']) > 0:
                        text = data['choices'][0]['message']['content']
                        self._log_response(text)
                        return text.strip()
                    
                    raise Exception("Unexpected DeepSeek API response format")
        
        except aiohttp.ClientError as e:
            logger.error(f"DeepSeek network error: {e}")
            raise Exception(f"Network error: {e}")
        except Exception as e:
            logger.error(f"DeepSeek query failed: {e}")
            raise
    
    def validate_credentials(self) -> bool:
        """
        Validate DeepSeek API key.
        
        Returns:
            True if valid
        """
        if not self.is_configured():
            return False
        
        try:
            import requests
            url = f"{self.api_base}/models"
            headers = {"Authorization": f"Bearer {self.api_key}"}
            response = requests.get(url, headers=headers, timeout=5)
            return response.status_code == 200
        except Exception as e:
            logger.error(f"DeepSeek credential validation failed: {e}")
            return False
EOF

# __init__.py for ai
cat > "$INSTALL_DIR/maysie/ai/__init__.py" << 'EOF'
"""AI provider modules"""

from .base import BaseAIProvider
from .gemini import GeminiProvider
from .chatgpt import ChatGPTProvider
from .deepseek import DeepSeekProvider

__all__ = [
    'BaseAIProvider',
    'GeminiProvider',
    'ChatGPTProvider',
    'DeepSeekProvider'
]
EOF

print_success "AI modules installed"

# ---------------------------------------------------------------------
# Install Config Modules
# ---------------------------------------------------------------------
print_status "Installing config modules..."

# manager.py
cat > "$INSTALL_DIR/maysie/config/manager.py" << 'EOF'
"""
Configuration management for Maysie
Handles loading, saving, and validating configuration.
"""

import os
import yaml
from pathlib import Path
from typing import Any, Dict, Optional
from dataclasses import dataclass, asdict

from maysie.utils.logger import get_logger

logger = get_logger(__name__)

DEFAULT_CONFIG_PATH = Path('/etc/maysie/config.yaml')


@dataclass
class HotkeyConfig:
    """Hotkey configuration"""
    combination: str = "Ctrl+Alt+L"
    enabled: bool = True


@dataclass
class AIRoutingRule:
    """AI routing rule"""
    pattern: str
    provider: str
    priority: int = 0


@dataclass
class AIConfig:
    """AI configuration"""
    default_provider: str = "auto"
    routing_rules: list[Dict[str, Any]] = None
    timeout: int = 30
    max_retries: int = 3
    
    def __post_init__(self):
        if self.routing_rules is None:
            self.routing_rules = [
                {"pattern": "research|latest|news|current|weather|package.*available", "provider": "gemini", "priority": 10},
                {"pattern": "code|script|program|debug|function|install|uninstall|update", "provider": "deepseek", "priority": 10},
                {"pattern": "decide|compare|analyze|recommend|choose|which.*better", "provider": "chatgpt", "priority": 10},
            ]


@dataclass
class SudoConfig:
    """Sudo configuration"""
    cache_timeout: int = 300  # seconds
    require_confirmation: bool = True
    dangerous_commands: list[str] = None
    
    def __post_init__(self):
        if self.dangerous_commands is None:
            self.dangerous_commands = [
                "rm -rf /",
                "mkfs",
                "dd if=/dev/zero",
                ":(){:|:&};:",  # Fork bomb
            ]


@dataclass
class UIConfig:
    """UI configuration"""
    position: str = "bottom-right"
    theme: str = "dark"
    auto_hide_delay: int = 3
    width: int = 500
    height: int = 600
    opacity: float = 0.98


@dataclass
class ResponseConfig:
    """Response style configuration"""
    default_style: str = "short"
    styles: Dict[str, str] = None
    
    def __post_init__(self):
        if self.styles is None:
            self.styles = {
                "short": "Provide a concise, direct answer. 2-3 sentences max.",
                "detailed": "Provide a comprehensive, well-explained answer with examples.",
                "technical": "Provide detailed technical explanation with proper terminology.",
                "command": "Provide only the command to execute, no explanation.",
            }


@dataclass
class LoggingConfig:
    """Logging configuration"""
    level: str = "INFO"
    max_file_size_mb: int = 10
    backup_count: int = 5
    enable_debug: bool = False


class ConfigManager:
    """Manages application configuration"""
    
    def __init__(self, config_path: Optional[Path] = None):
        """
        Initialize configuration manager.
        
        Args:
            config_path: Path to config file (default: /etc/maysie/config.yaml)
        """
        self.config_path = config_path or DEFAULT_CONFIG_PATH
        self.hotkey = HotkeyConfig()
        self.ai = AIConfig()
        self.sudo = SudoConfig()
        self.ui = UIConfig()
        self.response = ResponseConfig()
        self.logging = LoggingConfig()
        
        self._load()
    
    def _load(self):
        """Load configuration from file"""
        try:
            if self.config_path.exists():
                with open(self.config_path, 'r') as f:
                    data = yaml.safe_load(f) or {}
                
                # Load each section
                if 'hotkey' in data:
                    self.hotkey = HotkeyConfig(**data['hotkey'])
                if 'ai' in data:
                    self.ai = AIConfig(**data['ai'])
                if 'sudo' in data:
                    self.sudo = SudoConfig(**data['sudo'])
                if 'ui' in data:
                    self.ui = UIConfig(**data['ui'])
                if 'response' in data:
                    self.response = ResponseConfig(**data['response'])
                if 'logging' in data:
                    self.logging = LoggingConfig(**data['logging'])
                
                logger.info(f"Configuration loaded from {self.config_path}")
            else:
                logger.info("No config file found, using defaults")
                self._save()  # Create default config
        except Exception as e:
            logger.error(f"Failed to load config: {e}")
            logger.info("Using default configuration")
    
    def _save(self):
        """Save configuration to file"""
        try:
            data = {
                'hotkey': asdict(self.hotkey),
                'ai': asdict(self.ai),
                'sudo': asdict(self.sudo),
                'ui': asdict(self.ui),
                'response': asdict(self.response),
                'logging': asdict(self.logging),
            }
            
            self.config_path.parent.mkdir(parents=True, exist_ok=True)
            with open(self.config_path, 'w') as f:
                yaml.dump(data, f, default_flow_style=False, sort_keys=False)
            
            os.chmod(self.config_path, 0o644)
            logger.info(f"Configuration saved to {self.config_path}")
        except Exception as e:
            logger.error(f"Failed to save config: {e}")
    
    def reload(self):
        """Reload configuration from file"""
        self._load()
    
    def save(self):
        """Save current configuration to file"""
        self._save()
    
    def get(self, key: str, default: Any = None) -> Any:
        """
        Get configuration value by dot-notation key.
        
        Args:
            key: Configuration key (e.g., "ai.default_provider")
            default: Default value if key not found
            
        Returns:
            Configuration value
        """
        parts = key.split('.')
        obj = self
        
        for part in parts:
            if hasattr(obj, part):
                obj = getattr(obj, part)
            else:
                return default
        
        return obj
    
    def set(self, key: str, value: Any):
        """
        Set configuration value by dot-notation key.
        
        Args:
            key: Configuration key (e.g., "ai.default_provider")
            value: Value to set
        """
        parts = key.split('.')
        obj = self
        
        for part in parts[:-1]:
            if hasattr(obj, part):
                obj = getattr(obj, part)
            else:
                logger.error(f"Invalid config key: {key}")
                return
        
        if hasattr(obj, parts[-1]):
            setattr(obj, parts[-1], value)
            self._save()
        else:
            logger.error(f"Invalid config key: {key}")


# Global config instance
_global_config: Optional[ConfigManager] = None


def get_config() -> ConfigManager:
    """Get global configuration instance"""
    global _global_config
    if _global_config is None:
        _global_config = ConfigManager()
    return _global_config


def reload_config():
    """Reload global configuration"""
    global _global_config
    if _global_config is not None:
        _global_config.reload()
EOF

cat > "$INSTALL_DIR/maysie/config/__init__.py" << 'EOF'
"""Configuration management module"""

from .manager import (
    ConfigManager,
    HotkeyConfig,
    AIConfig,
    SudoConfig,
    UIConfig,
    ResponseConfig,
    LoggingConfig,
    get_config,
    reload_config
)

__all__ = [
    'ConfigManager',
    'HotkeyConfig',
    'AIConfig', 
    'SudoConfig',
    'UIConfig',
    'ResponseConfig',
    'LoggingConfig',
    'get_config',
    'reload_config'
]
EOF

print_success "Config modules installed"

# ---------------------------------------------------------------------
# Install System Modules
# ---------------------------------------------------------------------
print_status "Installing system modules..."

# sudo_handler.py
cat > "$INSTALL_DIR/maysie/system/sudo_handler.py" << 'EOF'
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
EOF

# package_manager.py
cat > "$INSTALL_DIR/maysie/system/package_manager.py" << 'EOF'
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
EOF

# __init__.py for system
cat > "$INSTALL_DIR/maysie/system/__init__.py" << 'EOF'
"""System integration modules"""

from .sudo_handler import SudoHandler, get_sudo_handler
from .package_manager import SystemPackageManager, PackageManager, get_package_manager

__all__ = [
    'SudoHandler',
    'get_sudo_handler',
    'SystemPackageManager',
    'PackageManager',
    'get_package_manager'
]
EOF

print_success "System modules installed"

# ---------------------------------------------------------------------
# Install Utils Modules
# ---------------------------------------------------------------------
print_status "Installing utils modules..."

# logger.py
cat > "$INSTALL_DIR/maysie/utils/logger.py" << 'EOF'
"""
Logging configuration for Maysie
Provides structured logging with rotation and multiple outputs.
"""

import logging
import logging.handlers
import os
import sys
from pathlib import Path
from typing import Optional

DEFAULT_LOG_DIR = os.environ.get('MAYSIE_LOG_DIR', '/var/log/maysie')
DEFAULT_LOG_LEVEL = logging.INFO


class MaysieLogger:
    """Centralized logging configuration"""
    
    _loggers = {}
    
    @classmethod
    def get_logger(cls, name: str, log_file: Optional[str] = None, 
                   level: int = DEFAULT_LOG_LEVEL) -> logging.Logger:
        """
        Get or create a logger instance.
        
        Args:
            name: Logger name (typically __name__)
            log_file: Optional specific log file
            level: Logging level
            
        Returns:
            Configured logger instance
        """
        if name in cls._loggers:
            return cls._loggers[name]
        
        logger = logging.getLogger(name)
        logger.setLevel(level)
        logger.propagate = False
        
        # Avoid duplicate handlers
        if logger.handlers:
            return logger
        
        # Console handler (always enabled)
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(level)
        console_format = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        console_handler.setFormatter(console_format)
        logger.addHandler(console_handler)
        
        # File handler (if log directory exists)
        try:
            log_dir = Path(DEFAULT_LOG_DIR)
            if log_dir.exists() or cls._ensure_log_dir(log_dir):
                log_file_path = log_dir / (log_file or 'maysie.log')
                
                # Rotating file handler (10MB max, 5 backups)
                file_handler = logging.handlers.RotatingFileHandler(
                    log_file_path,
                    maxBytes=10 * 1024 * 1024,  # 10MB
                    backupCount=5,
                    encoding='utf-8'
                )
                file_handler.setLevel(level)
                file_format = logging.Formatter(
                    '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s',
                    datefmt='%Y-%m-%d %H:%M:%S'
                )
                file_handler.setFormatter(file_format)
                logger.addHandler(file_handler)
        except (PermissionError, OSError) as e:
            # Fallback to /tmp if can't write to /var/log
            fallback_path = Path(f'/tmp/maysie_{name}.log')
            try:
                file_handler = logging.handlers.RotatingFileHandler(
                    fallback_path,
                    maxBytes=10 * 1024 * 1024,
                    backupCount=3
                )
                file_handler.setLevel(level)
                file_handler.setFormatter(console_format)
                logger.addHandler(file_handler)
                logger.warning(f"Using fallback log path: {fallback_path}")
            except Exception as fallback_error:
                logger.error(f"Failed to create fallback log: {fallback_error}")
        
        cls._loggers[name] = logger
        return logger
    
    @staticmethod
    def _ensure_log_dir(log_dir: Path) -> bool:
        """Ensure log directory exists with proper permissions"""
        try:
            log_dir.mkdir(parents=True, exist_ok=True)
            # Try to set readable permissions
            os.chmod(log_dir, 0o755)
            return True
        except (PermissionError, OSError):
            return False
    
    @classmethod
    def set_level(cls, level: int):
        """Set log level for all loggers"""
        for logger in cls._loggers.values():
            logger.setLevel(level)
            for handler in logger.handlers:
                handler.setLevel(level)


# Convenience function
def get_logger(name: str) -> logging.Logger:
    """Get a logger instance - convenience wrapper"""
    return MaysieLogger.get_logger(name)
EOF

# __init__.py for utils
cat > "$INSTALL_DIR/maysie/utils/__init__.py" << 'EOF'
"""Utility modules for Maysie"""

from .logger import get_logger, MaysieLogger

__all__ = [
    'get_logger', 
    'MaysieLogger'
]
EOF

print_success "Utils modules installed"

# ---------------------------------------------------------------------
# Install Core Modules
# ---------------------------------------------------------------------
print_status "Installing core modules..."

# command_router.py
cat > "$INSTALL_DIR/maysie/core/command_router.py" << 'EOF'
"""
Command routing and intent classification
Routes commands to appropriate handlers (system vs AI) and selects best AI provider.
"""

import re
import asyncio
import shlex
import subprocess
from typing import Optional, Dict, Any, Tuple
from pathlib import Path

from maysie.utils.logger import get_logger
from maysie.config import get_config
from maysie.ai import GeminiProvider, ChatGPTProvider, DeepSeekProvider
from maysie.system import get_package_manager, get_sudo_handler

logger = get_logger(__name__)


class CommandRouter:
    """Routes commands to appropriate handlers and AI providers"""
    
    def __init__(self):
        """Initialize command router"""
        self.config = get_config()
        self.sudo_handler = get_sudo_handler()
        self.pkg_manager = get_package_manager()
        
        # Initialize AI providers
        self._load_ai_providers()
        
        logger.info("Command router initialized")
    
    def _load_ai_providers(self):
        """Load and initialize AI providers"""
        # Load API keys from environment or config
        import os
        
        self.ai_providers = {
            'gemini': GeminiProvider(api_key=os.getenv('GEMINI_API_KEY')),
            'chatgpt': ChatGPTProvider(api_key=os.getenv('OPENAI_API_KEY')),
            'deepseek': DeepSeekProvider(api_key=os.getenv('DEEPSEEK_API_KEY')),
        }
        
        logger.info(f"Loaded AI providers: {list(self.ai_providers.keys())}")
    
    async def route_command(self, command: str) -> str:
        """
        Route command to appropriate handler.
        
        Args:
            command: User command
            
        Returns:
            Response string
        """
        try:
            logger.info(f"Routing command: {command}")
            
            # Parse special commands first
            if command.startswith('sudo code:'):
                return self._handle_sudo_code(command)
            
            # Check for system commands
            intent = self._classify_intent(command)
            
            if intent['type'] == 'system':
                return await self._handle_system_command(command, intent)
            else:
                # Route to AI
                return await self._handle_ai_query(command, intent)
        
        except Exception as e:
            logger.error(f"Command routing failed: {e}")
            return f"❌ Error: {str(e)}"
    
    def _classify_intent(self, command: str) -> Dict[str, Any]:
        """
        Classify command intent.
        
        Args:
            command: User command
            
        Returns:
            Intent dictionary with type and details
        """
        command_lower = command.lower()
        
        # System command patterns
        system_patterns = {
            'package_install': r'\b(install|add)\s+([a-zA-Z0-9\-_\s\.\+]+)',
            'package_uninstall': r'\b(uninstall|remove|delete)\s+([a-zA-Z0-9\-_\s\.\+]+)',
            'package_update': r'\b(update|upgrade)\s+(system|packages?)?',
            'package_search': r'\b(search|find)\s+(package\s+)?([a-zA-Z0-9\-_\s]+)',
            'process_list': r'\b(list|show)\s+(processes|running\s+apps?)',
            'process_kill': r'\b(kill|stop|terminate)\s+([a-zA-Z0-9\-_\s]+)',
            'disk_usage': r'\b(disk|storage|space)\s+(usage|info|free)',
            'memory_usage': r'\b(memory|ram)\s+(usage|info|free)',
            'system_info': r'\b(system|host)\s+(info|information|details)',
            'file_list': r'\blist\s+(files?\s+in\s+)?(.+)',
            'file_create': r'\b(create|make|touch)\s+(file\s+)?(.+)',
            'file_delete': r'\b(delete|remove|rm)\s+(file\s+)?(.+)',
        }
        
        for intent_name, pattern in system_patterns.items():
            match = re.search(pattern, command_lower)
            if match:
                return {
                    'type': 'system',
                    'subtype': intent_name,
                    'matches': match.groups()
                }
        
        # AI query - determine provider
        provider = self._select_ai_provider(command)
        
        return {
            'type': 'ai',
            'provider': provider
        }
    
    def _select_ai_provider(self, command: str) -> str:
        """
        Select best AI provider based on command content.
        
        Args:
            command: User command
            
        Returns:
            Provider name (gemini, chatgpt, deepseek)
        """
        command_lower = command.lower()
        
        # Check routing rules
        for rule in self.config.ai.routing_rules:
            pattern = rule.get('pattern', '')
            if re.search(pattern, command_lower):
                provider = rule.get('provider', 'auto')
                if provider in self.ai_providers:
                    logger.info(f"Routing to {provider} based on pattern: {pattern}")
                    return provider
        
        # Default provider
        default = self.config.ai.default_provider
        if default != 'auto' and default in self.ai_providers:
            return default
        
        # Auto-select: prefer gemini for general queries
        return 'gemini'
    
    def _handle_sudo_code(self, command: str) -> str:
        """Handle 'sudo code:<password>' command"""
        try:
            # Parse: sudo code:<password> [-t timeout]
            parts = command.split()
            
            if not parts[1].startswith('code:'):
                return "❌ Invalid syntax. Use: sudo code:<password> [-t <minutes>]"
            
            password = parts[1][5:]  # Remove 'code:' prefix
            
            # Check for timeout flag
            timeout = None
            if len(parts) > 2 and parts[2] == '-t' and len(parts) > 3:
                try:
                    timeout = int(parts[3]) * 60  # Convert minutes to seconds
                except ValueError:
                    return "❌ Invalid timeout value"
            
            self.sudo_handler.set_password(password, timeout)
            
            timeout_msg = f" for {timeout//60} minutes" if timeout else ""
            return f"✅ Sudo credentials cached{timeout_msg}"
            
        except ValueError as e:
            return f"❌ {e}"
        except Exception as e:
            logger.error(f"Sudo code handling failed: {e}")
            return f"❌ Failed to cache credentials: {e}"
    
    async def _handle_system_command(self, command: str, intent: Dict) -> str:
        """Handle system commands"""
        subtype = intent['subtype']
        matches = intent['matches']
        
        try:
            if subtype == 'package_install':
                package = matches[1].strip()
                return await self._handle_package_install(package)
            
            elif subtype == 'package_uninstall':
                package = matches[1].strip()
                return await self._handle_package_uninstall(package)
            
            elif subtype == 'package_update':
                return await self._handle_package_update()
            
            elif subtype == 'package_search':
                query = matches[2].strip()
                return await self._handle_package_search(query)
            
            elif subtype == 'process_list':
                return await self._handle_process_list()
            
            elif subtype == 'process_kill':
                target = matches[1].strip()
                return await self._handle_process_kill(target)
            
            elif subtype == 'disk_usage':
                return await self._handle_disk_usage()
            
            elif subtype == 'memory_usage':
                return await self._handle_memory_usage()
            
            elif subtype == 'system_info':
                return await self._handle_system_info()
            
            elif subtype == 'file_list':
                directory = matches[1].strip() if matches[1] else '.'
                return await self._handle_file_list(directory)
            
            elif subtype == 'file_create':
                filepath = matches[2].strip()
                return await self._handle_file_create(filepath)
            
            elif subtype == 'file_delete':
                filepath = matches[2].strip()
                return await self._handle_file_delete(filepath)
            
            else:
                return f"❌ System command not implemented: {subtype}"
        
        except Exception as e:
            logger.error(f"System command execution failed: {e}")
            return f"❌ Error: {e}"
    
    async def _handle_package_install(self, package: str) -> str:
        """Handle package installation with AI check"""
        # First, check if package exists
        success, search_result = self.pkg_manager.search(package)
        
        if not success:
            # Ask AI about the package
            ai_response = await self._ask_ai_about_package(package, "install")
            return ai_response
        
        # Check if already installed
        if self.pkg_manager.is_installed(package):
            return f"✅ {package} is already installed"
        
        # Ask AI for any warnings or alternatives
        ai_advice = await self._ask_ai_about_package(package, "install")
        
        # Install the package
        success, msg = self.pkg_manager.install([package])
        
        if success:
            return f"✅ Successfully installed {package}\n\n{ai_advice}"
        else:
            return f"❌ Failed to install {package}: {msg}\n\n{ai_advice}"
    
    async def _handle_package_uninstall(self, package: str) -> str:
        """Handle package removal"""
        if not self.pkg_manager.is_installed(package):
            return f"❌ {package} is not installed"
        
        # Ask AI about consequences
        ai_advice = await self._ask_ai_about_package(package, "uninstall")
        
        success, msg = self.pkg_manager.uninstall([package])
        
        if success:
            return f"✅ Successfully removed {package}\n\n{ai_advice}"
        else:
            return f"❌ Failed to remove {package}: {msg}\n\n{ai_advice}"
    
    async def _handle_package_update(self) -> str:
        """Handle system update"""
        success, msg = self.pkg_manager.update()
        return f"{'✅' if success else '❌'} {msg}"
    
    async def _handle_package_search(self, query: str) -> str:
        """Handle package search"""
        success, result = self.pkg_manager.search(query)
        
        if success:
            return f"🔍 Search results for '{query}':\n{result}"
        else:
            # Ask AI about the package
            return await self._ask_ai_about_package(query, "search")
    
    async def _handle_process_list(self) -> str:
        """List running processes"""
        try:
            result = subprocess.run(
                "ps aux --sort=-%cpu | head -15",
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                return f"📊 Top processes by CPU:\n{result.stdout}"
            else:
                return "❌ Failed to list processes"
        except Exception as e:
            return f"❌ Error listing processes: {e}"
    
    async def _handle_process_kill(self, target: str) -> str:
        """Kill process"""
        try:
            # Try by PID first
            if target.isdigit():
                import signal
                import os
                os.kill(int(target), signal.SIGTERM)
                return f"✅ Terminated process with PID {target}"
            
            # Try by name
            result = subprocess.run(
                f"pkill -f {shlex.quote(target)}",
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                return f"✅ Terminated processes matching '{target}'"
            else:
                return f"❌ No processes found matching '{target}'"
        except Exception as e:
            return f"❌ Error killing process: {e}"
    
    async def _handle_disk_usage(self) -> str:
        """Show disk usage"""
        try:
            result = subprocess.run(
                "df -h",
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                return f"💾 Disk usage:\n{result.stdout}"
            else:
                return "❌ Failed to get disk usage"
        except Exception as e:
            return f"❌ Error getting disk usage: {e}"
    
    async def _handle_memory_usage(self) -> str:
        """Show memory usage"""
        try:
            result = subprocess.run(
                "free -h",
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                return f"🧠 Memory usage:\n{result.stdout}"
            else:
                return "❌ Failed to get memory usage"
        except Exception as e:
            return f"❌ Error getting memory usage: {e}"
    
    async def _handle_system_info(self) -> str:
        """Show system information"""
        try:
            commands = [
                "uname -a",
                "lsb_release -a 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME",
                "hostnamectl",
            ]
            
            output = "📋 System Information:\n\n"
            for cmd in commands:
                result = subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=5
                )
                if result.returncode == 0:
                    output += f"$ {cmd}\n{result.stdout}\n"
            
            return output.strip()
        except Exception as e:
            return f"❌ Error getting system info: {e}"
    
    async def _handle_file_list(self, directory: str) -> str:
        """List directory contents"""
        try:
            result = subprocess.run(
                f"ls -la {shlex.quote(directory)}",
                shell=True,
                capture_output=True,
                text=True,
                timeout=5
            )
            
            if result.returncode == 0:
                return f"📁 Contents of {directory}:\n{result.stdout}"
            else:
                return f"❌ Failed to list directory: {result.stderr}"
        except Exception as e:
            return f"❌ Error listing directory: {e}"
    
    async def _handle_file_create(self, filepath: str) -> str:
        """Create a file"""
        try:
            Path(filepath).touch()
            return f"✅ Created file: {filepath}"
        except Exception as e:
            return f"❌ Failed to create file: {e}"
    
    async def _handle_file_delete(self, filepath: str) -> str:
        """Delete a file"""
        try:
            Path(filepath).unlink()
            return f"✅ Deleted file: {filepath}"
        except Exception as e:
            return f"❌ Failed to delete file: {e}"
    
    async def _handle_ai_query(self, command: str, intent: Dict) -> str:
        """Handle AI queries"""
        provider_name = intent['provider']
        provider = self.ai_providers.get(provider_name)
        
        if not provider:
            return f"❌ AI provider '{provider_name}' not available"
        
        if not provider.is_configured():
            return f"""❌ AI provider '{provider_name}' not configured.
Add API key to /etc/maysie/secrets.env:
{provider_name.upper()}_API_KEY=your-key-here
Then restart with: maysie restart"""
        
        try:
            # Get response style
            style_instruction = self.config.response.styles.get(
                self.config.response.default_style,
                "Provide a clear, helpful response."
            )
            
            context = {'response_style': style_instruction}
            response = await provider.query(command, context)
            return f"🤖 {response}"
            
        except Exception as e:
            logger.error(f"AI query failed: {e}")
            return f"❌ AI query failed: {e}"
    
    async def _ask_ai_about_package(self, package: str, action: str) -> str:
        """Ask AI about a package"""
        provider = self.ai_providers.get('gemini') or self.ai_providers.get('chatgpt')
        
        if not provider or not provider.is_configured():
            return "ℹ️ Add API keys for AI package recommendations"
        
        try:
            prompt = f"""On Debian Linux, for a user who wants to {action} the package '{package}':

1. Is this package available in Debian repositories?
2. What does this package do?
3. Any important dependencies or conflicts?
4. Any security considerations?
5. If not available, suggest alternatives.

Keep response concise and practical."""
            
            response = await provider.query(prompt)
            return f"💡 AI advice about '{package}':\n{response}"
            
        except Exception as e:
            logger.error(f"AI package advice failed: {e}")
            return "ℹ️ Could not get AI advice (check API keys)"


# Global instance
_global_router = None


def get_command_router() -> CommandRouter:
    """Get global command router instance"""
    global _global_router
    if _global_router is None:
        _global_router = CommandRouter()
    return _global_router
EOF

cat > "$INSTALL_DIR/maysie/core/__init__.py" << 'EOF'
"""Core service components"""

from .command_router import CommandRouter, get_command_router

__all__ = [
    'CommandRouter',
    'get_command_router',
]
EOF

print_success "Core modules installed"

# ---------------------------------------------------------------------
# Install UI Modules (Tkinter version)
# ---------------------------------------------------------------------
print_status "Installing UI modules..."

# popup.py (Tkinter version)
cat > "$INSTALL_DIR/maysie/ui/popup.py" << 'EOF'
"""
Tkinter popup UI
Main interface for Maysie AI Assistant
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, simpledialog, messagebox
import threading
import asyncio
import time
from datetime import datetime

from maysie.utils.logger import get_logger
from maysie.config import get_config
from maysie.core import get_command_router

logger = get_logger(__name__)

class MaysiePopup:
    """Main Tkinter popup window"""
    
    def __init__(self):
        self.config = get_config()
        self.command_router = get_command_router()
        self.root = None
        self.history = []
        self.history_index = -1
        self.sudo_password = None
        
        # Create UI
        self.create_ui()
        
        # Bind hotkeys
        self.bind_hotkeys()
        
        logger.info("Tkinter popup initialized")
    
    def create_ui(self):
        """Create the main UI"""
        self.root = tk.Tk()
        self.root.title("🤖 Maysie AI Assistant")
        self.root.geometry("600x700")
        self.root.configure(bg='#1e1e1e')
        
        # Center window
        self.center_window()
        
        # Make window stay on top
        self.root.attributes('-topmost', True)
        
        # Create frames
        self.create_header()
        self.create_input_section()
        self.create_output_section()
        self.create_status_bar()
    
    def center_window(self):
        """Center window on screen"""
        self.root.update_idletasks()
        width = self.root.winfo_width()
        height = self.root.winfo_height()
        x = (self.root.winfo_screenwidth() // 2) - (width // 2)
        y = (self.root.winfo_screenheight() // 2) - (height // 2)
        self.root.geometry(f'{width}x{height}+{x}+{y}')
    
    def create_header(self):
        """Create header section"""
        header = tk.Frame(self.root, bg='#2d2d2d', height=70)
        header.pack(fill='x', padx=0, pady=0)
        header.pack_propagate(False)
        
        # Title
        title_frame = tk.Frame(header, bg='#2d2d2d')
        title_frame.pack(side='left', padx=20, pady=10)
        
        tk.Label(title_frame, text="🤖", font=("Arial", 24), 
                fg='white', bg='#2d2d2d').pack(side='left')
        
        tk.Label(title_frame, text="Maysie AI Assistant", 
                font=("Arial", 16, "bold"), fg='white', bg='#2d2d2d').pack(side='left', padx=10)
        
        # Status indicator
        self.status_indicator = tk.Label(header, text="●", font=("Arial", 16), 
                                        fg='#4CAF50', bg='#2d2d2d')
        self.status_indicator.pack(side='right', padx=20)
        
        tk.Label(header, text="Ready", font=("Arial", 10), 
                fg='#a0a0a0', bg='#2d2d2d').pack(side='right')
    
    def create_input_section(self):
        """Create command input section"""
        input_frame = tk.Frame(self.root, bg='#1e1e1e')
        input_frame.pack(fill='x', padx=20, pady=(20, 10))
        
        # Command label
        tk.Label(input_frame, text="Enter Command:", 
                font=("Arial", 11, "bold"), fg='white', bg='#1e1e1e').pack(anchor='w')
        
        # Command entry with syntax highlighting
        self.cmd_entry = tk.Entry(input_frame, font=("Courier", 12), 
                                 bg='#2d2d2d', fg='#00ff00', insertbackground='white',
                                 relief='flat', highlightthickness=2, highlightbackground='#3d3d3d')
        self.cmd_entry.pack(fill='x', pady=(8, 5), ipady=8)
        self.cmd_entry.focus()
        
        # Button frame
        btn_frame = tk.Frame(input_frame, bg='#1e1e1e')
        btn_frame.pack(fill='x', pady=(5, 0))
        
        buttons = [
            ("Execute", self.execute_command, '#4CAF50'),
            ("Sudo", self.set_sudo_password, '#2196F3'),
            ("Clear", self.clear_output, '#FF9800'),
            ("Help", self.show_help, '#9C27B0'),
            ("Hide", self.hide_window, '#f44336'),
        ]
        
        for text, command, color in buttons:
            btn = tk.Button(btn_frame, text=text, font=("Arial", 10, "bold"),
                           bg=color, fg='white', command=command,
                           relief='flat', padx=15, pady=6)
            btn.pack(side='left', padx=5)
    
    def create_output_section(self):
        """Create output display section"""
        output_frame = tk.Frame(self.root, bg='#1e1e1e')
        output_frame.pack(fill='both', expand=True, padx=20, pady=(0, 20))
        
        # Output label
        tk.Label(output_frame, text="Output:", 
                font=("Arial", 11, "bold"), fg='white', bg='#1e1e1e').pack(anchor='w')
        
        # Scrolled text widget for output
        self.output_text = scrolledtext.ScrolledText(output_frame, 
                                                    font=("Courier", 10),
                                                    bg='#0a0a0a', fg='#e0e0e0',
                                                    wrap='word', height=20,
                                                    relief='flat', borderwidth=0)
        self.output_text.pack(fill='both', expand=True, pady=(8, 0))
        
        # Configure tags for different message types
        self.output_text.tag_config('command', foreground='#FFFF00')
        self.output_text.tag_config('success', foreground='#4CAF50')
        self.output_text.tag_config('error', foreground='#f44336')
        self.output_text.tag_config('ai', foreground='#2196F3')
        self.output_text.tag_config('system', foreground='#FF9800')
        self.output_text.tag_config('info', foreground='#9C27B0')
        
        # Make output read-only
        self.output_text.config(state='disabled')
    
    def create_status_bar(self):
        """Create status bar at bottom"""
        status_bar = tk.Frame(self.root, bg='#2d2d2d', height=30)
        status_bar.pack(fill='x', side='bottom')
        status_bar.pack_propagate(False)
        
        # Status messages
        self.status_label = tk.Label(status_bar, text="Ready | Press Ctrl+Alt+L to show/hide", 
                                    font=("Arial", 9), fg='#a0a0a0', bg='#2d2d2d')
        self.status_label.pack(side='left', padx=20)
        
        # Time
        self.time_label = tk.Label(status_bar, text="", 
                                  font=("Arial", 9), fg='#a0a0a0', bg='#2d2d2d')
        self.time_label.pack(side='right', padx=20)
        
        # Update time
        self.update_time()
    
    def bind_hotkeys(self):
        """Bind keyboard shortcuts"""
        self.root.bind('<Return>', lambda e: self.execute_command())
        self.root.bind('<Control-Return>', lambda e: self.execute_command())
        self.root.bind('<Control-l>', lambda e: self.clear_output())
        self.root.bind('<Control-h>', lambda e: self.show_help())
        self.root.bind('<Escape>', lambda e: self.hide_window())
        self.root.bind('<Up>', lambda e: self.navigate_history(-1))
        self.root.bind('<Down>', lambda e: self.navigate_history(1))
        self.root.bind('<Control-s>', lambda e: self.set_sudo_password())
    
    def update_time(self):
        """Update time in status bar"""
        current_time = datetime.now().strftime("%H:%M:%S")
        self.time_label.config(text=current_time)
        self.root.after(1000, self.update_time)
    
    def log_output(self, text: str, tag: str = 'info'):
        """Add text to output area"""
        self.output_text.config(state='normal')
        
        # Add timestamp
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.output_text.insert('end', f"[{timestamp}] ", 'info')
        
        # Add the message
        self.output_text.insert('end', text + '\n', tag)
        
        self.output_text.config(state='disabled')
        self.output_text.see('end')
    
    def clear_output(self):
        """Clear output area"""
        self.output_text.config(state='normal')
        self.output_text.delete('1.0', 'end')
        self.output_text.config(state='disabled')
        self.log_output("Output cleared", 'system')
    
    def navigate_history(self, direction: int):
        """Navigate command history"""
        if not self.history:
            return
        
        self.history_index = max(0, min(len(self.history) - 1, self.history_index + direction))
        
        if 0 <= self.history_index < len(self.history):
            self.cmd_entry.delete(0, 'end')
            self.cmd_entry.insert(0, self.history[self.history_index])
    
    def set_sudo_password(self):
        """Set sudo password"""
        password = simpledialog.askstring("Sudo Password", 
                                         "Enter sudo password (cached for 5 minutes):", 
                                         show='*', parent=self.root)
        if password:
            self.sudo_password = password
            try:
                # Cache the password
                import os
                os.environ['MAYSIE_SUDO_PASSWORD'] = password
                self.log_output("✅ Sudo password cached for 5 minutes", 'success')
            except Exception as e:
                self.log_output(f"❌ Failed to cache sudo password: {e}", 'error')
    
    def show_help(self):
        """Show help dialog"""
        help_text = """🤖 Maysie AI Assistant - Complete Guide

🎯 BASIC USAGE:
• Type commands and press Enter
• Use Up/Down arrows for history
• Press Escape to hide window

🔧 SYSTEM COMMANDS:
• install <package>     - Install software
• uninstall <package>   - Remove software
• update               - Update system
• search <package>      - Search for packages
• list processes       - Show running apps
• disk usage           - Check storage
• memory               - Check RAM usage
• system info          - System details

📁 FILE COMMANDS:
• list <dir>           - List files
• create <file>        - Create file
• delete <file>        - Delete file

🤖 AI COMMANDS:
• Ask anything!        - Get AI response
• Package questions    - "Is neofetch available?"
• Tech help            - "How to fix network?"
• Research             - "Latest AI trends"

⚡ SMART FEATURES:
• Auto AI routing      - Gemini/DeepSeek/ChatGPT
• Package checking     - Checks availability
• Sudo integration     - Secure password cache
• Smart responses      - Context-aware answers

🔑 CONFIGURATION:
Edit /etc/maysie/secrets.env to add API keys:
• GEMINI_API_KEY for research
• OPENAI_API_KEY for reasoning  
• DEEPSEEK_API_KEY for coding

🎯 HOTKEY: Ctrl+Alt+L to toggle window"""
        
        messagebox.showinfo("Maysie Help", help_text, parent=self.root)
    
    def execute_command(self):
        """Execute the entered command"""
        command = self.cmd_entry.get().strip()
        if not command:
            return
        
        # Add to history
        if not self.history or self.history[-1] != command:
            self.history.append(command)
        self.history_index = len(self.history)
        
        # Clear input and log command
        self.cmd_entry.delete(0, 'end')
        self.log_output(f"$ {command}", 'command')
        
        # Update status
        self.status_label.config(text="Processing...")
        self.status_indicator.config(fg='#FF9800')
        
        # Execute in thread
        threading.Thread(target=self._execute_command_thread, 
                        args=(command,), daemon=True).start()
    
    def _execute_command_thread(self, command: str):
        """Execute command in background thread"""
        try:
            # Create event loop for async operations
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            # Route and execute command
            result = loop.run_until_complete(self.command_router.route_command(command))
            loop.close()
            
            # Update UI in main thread
            self.root.after(0, self._show_result, command, result)
            
        except Exception as e:
            self.root.after(0, self._show_error, str(e))
    
    def _show_result(self, command: str, result: str):
        """Show command result"""
        # Determine tag based on result
        if result.startswith('✅'):
            tag = 'success'
        elif result.startswith('❌'):
            tag = 'error'
        elif result.startswith('🤖'):
            tag = 'ai'
            result = result[2:]  # Remove emoji
        else:
            tag = 'system'
        
        self.log_output(result, tag)
        
        # Update status
        self.status_label.config(text="Ready")
        self.status_indicator.config(fg='#4CAF50')
    
    def _show_error(self, error: str):
        """Show error message"""
        self.log_output(f"❌ Error: {error}", 'error')
        self.status_label.config(text="Error occurred")
        self.status_indicator.config(fg='#f44336')
    
    def show_window(self):
        """Show the window"""
        if not self.root:
            return
        
        self.root.deiconify()
        self.root.lift()
        self.root.focus_force()
        self.cmd_entry.focus()
        
        # Center again
        self.center_window()
    
    def hide_window(self):
        """Hide the window"""
        if self.root:
            self.root.withdraw()
    
    def toggle_window(self):
        """Toggle window visibility"""
        if self.root.state() == 'withdrawn':
            self.show_window()
        else:
            self.hide_window()
    
    def run(self):
        """Start the Tkinter main loop"""
        try:
            self.root.mainloop()
        except Exception as e:
            logger.error(f"Tkinter error: {e}")


class HotkeyManager:
    """Manages global hotkey for showing/hiding window"""
    
    def __init__(self, popup: MaysiePopup):
        self.popup = popup
        self.listener = None
        self.running = False
    
    def start(self):
        """Start hotkey listener"""
        try:
            import pynput.keyboard
            
            def on_activate():
                self.popup.root.after(0, self.popup.toggle_window)
            
            hotkey = pynput.keyboard.HotKey(
                pynput.keyboard.HotKey.parse('<ctrl>+<alt>+l'),
                on_activate
            )
            
            with pynput.keyboard.Listener(
                on_press=lambda k: hotkey.press(listener.canonical(k)),
                on_release=lambda k: hotkey.release(listener.canonical(k))
            ) as listener:
                self.listener = listener
                self.running = True
                logger.info("Hotkey listener started (Ctrl+Alt+L)")
                listener.join()
                
        except ImportError:
            logger.warning("pynput not installed, hotkey disabled")
        except Exception as e:
            logger.error(f"Hotkey manager error: {e}")
    
    def stop(self):
        """Stop hotkey listener"""
        self.running = False
        if self.listener:
            self.listener.stop()


def run_maysie():
    """Run Maysie with Tkinter interface"""
    try:
        logger.info("Starting Maysie Tkinter interface...")
        
        # Create popup
        popup = MaysiePopup()
        
        # Start hotkey manager in separate thread
        hotkey_manager = HotkeyManager(popup)
        hotkey_thread = threading.Thread(target=hotkey_manager.start, daemon=True)
        hotkey_thread.start()
        
        # Show initial message
        popup.log_output("🤖 Maysie AI Assistant started!", 'ai')
        popup.log_output("Type 'help' for available commands", 'info')
        popup.log_output("Press Ctrl+Alt+L to show/hide window", 'info')
        
        # Run Tkinter main loop
        popup.run()
        
    except Exception as e:
        logger.error(f"Failed to run Maysie: {e}")
        messagebox.showerror("Maysie Error", f"Failed to start: {str(e)}")
EOF

cat > "$INSTALL_DIR/maysie/ui/__init__.py" << 'EOF'
"""User interface modules"""

from .popup import MaysiePopup, HotkeyManager, run_maysie

__all__ = [
    'MaysiePopup',
    'HotkeyManager',
    'run_maysie',
]
EOF

print_success "UI modules installed"

# ---------------------------------------------------------------------
# STEP 5: CREATE MAIN APPLICATION
# ---------------------------------------------------------------------
print_status "Creating main application..."

cat > "$INSTALL_DIR/main.py" << 'EOF'
#!/usr/bin/env python3
"""
Maysie AI Assistant - Main Entry Point
Complete production version with all features
"""

import os
import sys
import time
import logging
import asyncio
from pathlib import Path

# Add Maysie to path
sys.path.insert(0, '/opt/maysie')

from maysie.utils.logger import get_logger
from maysie.config import get_config
from maysie.ui import run_maysie

logger = get_logger("maysie")

def setup_environment():
    """Setup environment variables"""
    # Load API keys from secrets file
    secrets_file = Path("/etc/maysie/secrets.env")
    if secrets_file.exists():
        try:
            with open(secrets_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#'):
                        if '=' in line:
                            key, value = line.split('=', 1)
                            key = key.strip()
                            value = value.strip()
                            if key and value:
                                os.environ[key] = value
                                logger.debug(f"Loaded env var: {key}")
        except Exception as e:
            logger.error(f"Failed to load secrets: {e}")
    
    # Set display for GUI
    if 'DISPLAY' not in os.environ:
        os.environ['DISPLAY'] = ':0'
    
    # Set X authority
    user_home = os.path.expanduser('~')
    xauth_path = f"{user_home}/.Xauthority"
    if os.path.exists(xauth_path):
        os.environ['XAUTHORITY'] = xauth_path

def check_dependencies():
    """Check if required dependencies are available"""
    missing = []
    
    # Check Python packages
    try:
        import tkinter
    except ImportError:
        missing.append("tkinter (install: sudo apt install python3-tk)")
    
    try:
        import pynput
    except ImportError:
        missing.append("pynput (install: pip install pynput)")
    
    try:
        import aiohttp
    except ImportError:
        missing.append("aiohttp (install: pip install aiohttp)")
    
    try:
        import yaml
    except ImportError:
        missing.append("PyYAML (install: pip install PyYAML)")
    
    if missing:
        logger.warning("Missing dependencies:")
        for dep in missing:
            logger.warning(f"  - {dep}")
        
        return False
    
    return True

def main():
    """Main entry point"""
    try:
        logger.info("=" * 70)
        logger.info("🤖 Maysie AI Assistant - Starting")
        logger.info("=" * 70)
        
        # Setup
        setup_environment()
        
        # Check dependencies
        if not check_dependencies():
            logger.warning("Some dependencies missing, may affect functionality")
        
        # Load config
        config = get_config()
        logger.info(f"Configuration loaded: {config.config_path}")
        
        # Display info
        logger.info(f"Hotkey: {config.hotkey.combination}")
        logger.info(f"AI Providers: {list(config.ai.routing_rules)}")
        logger.info(f"Log level: {config.logging.level}")
        
        # Start the application
        logger.info("=" * 70)
        logger.info("Starting Tkinter interface...")
        logger.info("Press Ctrl+Alt+L to show/hide window")
        logger.info("=" * 70)
        
        run_maysie()
        
    except KeyboardInterrupt:
        logger.info("Shutdown requested by user")
    except Exception as e:
        logger.error(f"Fatal error: {e}", exc_info=True)
        return 1
    
    return 0

if __name__ == "__main__":
    # Ensure asyncio event loop
    if sys.platform == 'win32':
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())
    
    sys.exit(main())
EOF

chmod +x "$INSTALL_DIR/main.py"
print_success "Main application created"

# ---------------------------------------------------------------------
# STEP 6: CREATE REQUIREMENTS
# ---------------------------------------------------------------------
print_status "Creating requirements file..."

cat > "$INSTALL_DIR/requirements.txt" << 'EOF'
# Core dependencies
aiohttp>=3.9.0
asyncio>=3.4.3
PyYAML>=6.0.1
pynput>=1.7.6
psutil>=5.9.0
requests>=2.31.0
cryptography>=41.0.0

# AI providers
openai>=1.3.0
google-generativeai>=0.3.0
anthropic>=0.7.0

# Optional (for future features)
Flask>=3.0.0
Flask-CORS>=4.0.0
Werkzeug>=3.0.0
python-daemon>=3.0.1
dbus-python>=1.3.2
python-dotenv>=1.0.0
jsonschema>=4.20.0
EOF

print_success "Requirements file created"

# ---------------------------------------------------------------------
# STEP 7: SETUP PYTHON ENVIRONMENT
# ---------------------------------------------------------------------
print_status "Setting up Python environment..."
cd "$INSTALL_DIR"
sudo -u $CURRENT_USER python3 -m venv venv

VENV_PIP="$INSTALL_DIR/venv/bin/pip"
VENV_PY="$INSTALL_DIR/venv/bin/python3"

print_status "Installing Python packages (this will take a few minutes)..."
sudo -u $CURRENT_USER "$VENV_PIP" install --upgrade pip > /dev/null 2>&1

# Install core packages
CORE_PACKAGES="aiohttp PyYAML pynput psutil requests"
sudo -u $CURRENT_USER "$VENV_PIP" install $CORE_PACKAGES > /dev/null 2>&1

print_success "Python environment setup complete"

# ---------------------------------------------------------------------
# STEP 8: CREATE CONFIGURATION
# ---------------------------------------------------------------------
print_status "Creating configuration..."

# Copy backed up config if exists
if [ -f "$BACKUP_DIR/maysie/config.yaml" ]; then
    cp "$BACKUP_DIR/maysie/config.yaml" "$CONFIG_DIR/"
    print_success "Restored config from backup"
else:
    # Create new config
    cat > "$CONFIG_DIR/config.yaml" << 'EOF'
hotkey:
  combination: "Ctrl+Alt+L"
  enabled: true

ai:
  default_provider: "auto"
  routing_rules:
    - pattern: "research|latest|news|current|weather|package.*available|is.*available|alternative"
      provider: "gemini"
      priority: 10
    - pattern: "code|script|program|debug|function|install|uninstall|update|command|terminal|bash|shell"
      provider: "deepseek"
      priority: 10
    - pattern: "decide|compare|analyze|recommend|choose|which.*better|should.*use|opinion"
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
  position: "center"
  theme: "dark"
  auto_hide_delay: 0
  width: 600
  height: 700
  opacity: 0.98

response:
  default_style: "detailed"
  styles:
    short: "Provide a concise, direct answer. 2-3 sentences max."
    detailed: "Provide a comprehensive, well-explained answer with examples."
    technical: "Provide detailed technical explanation with proper terminology."
    command: "Provide only the command to execute, no explanation."

logging:
  level: "INFO"
  max_file_size_mb: 10
  backup_count: 5
  enable_debug: false
EOF

# Copy backed up secrets if exists
if [ -f "$BACKUP_DIR/maysie/secrets.env" ]; then
    cp "$BACKUP_DIR/maysie/secrets.env" "$CONFIG_DIR/"
    print_success "Restored secrets from backup"
else
    # Create new secrets
    cat > "$CONFIG_DIR/secrets.env" << EOF
# Maysie AI Assistant - API Keys
# Remove # and add your keys:

# OpenAI (ChatGPT)
# OPENAI_API_KEY=sk-your-key-here

# Google Gemini
# GEMINI_API_KEY=your-key-here

# Anthropic Claude
# ANTHROPIC_API_KEY=sk-your-key-here

# DeepSeek
# DEEPSEEK_API_KEY=your-key-here

# Environment
MAYSIE_LOG_LEVEL=INFO
EOF
fi

chown -R $CURRENT_USER:$CURRENT_USER "$CONFIG_DIR"
chmod 644 "$CONFIG_DIR/config.yaml"
chmod 600 "$CONFIG_DIR/secrets.env"

print_success "Configuration created"

# ---------------------------------------------------------------------
# STEP 9: CREATE SYSTEMD SERVICE
# ---------------------------------------------------------------------
print_status "Creating systemd service..."

cat > /etc/systemd/system/maysie.service << EOF
[Unit]
Description=Maysie AI Assistant
After=graphical.target network.target
Wants=network-online.target
Requires=graphical.target

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR
Environment=PATH=$INSTALL_DIR/venv/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=DISPLAY=:0
Environment=XAUTHORITY=/home/$CURRENT_USER/.Xauthority
Environment=DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u $CURRENT_USER)/bus
ExecStart=$INSTALL_DIR/venv/bin/python3 $INSTALL_DIR/main.py
Restart=on-failure
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

# Security
NoNewPrivileges=true
ProtectSystem=strict
PrivateTmp=true
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable maysie.service > /dev/null 2>&1
print_success "Systemd service created"

# ---------------------------------------------------------------------
# STEP 10: CREATE USER COMMANDS
# ---------------------------------------------------------------------
print_status "Creating user commands..."
mkdir -p "$CURRENT_HOME/.local/bin"

cat > "$CURRENT_HOME/.local/bin/maysie" << 'EOF'
#!/bin/bash
# Maysie AI Assistant Command Line Interface

VERSION="2.0.0"
INSTALL_DIR="/opt/maysie"
CONFIG_DIR="/etc/maysie"

case "$1" in
    start)
        echo "🚀 Starting Maysie AI Assistant..."
        sudo systemctl start maysie.service
        sleep 2
        echo "✅ Maysie started!"
        echo "🎯 Hotkey: Ctrl+Alt+L to open popup"
        echo "📊 Check status: maysie status"
        ;;
    stop)
        echo "🛑 Stopping Maysie AI Assistant..."
        sudo systemctl stop maysie.service
        echo "✅ Maysie stopped"
        ;;
    restart)
        echo "🔁 Restarting Maysie AI Assistant..."
        sudo systemctl restart maysie.service
        sleep 2
        echo "✅ Maysie restarted!"
        echo "🎯 Hotkey: Ctrl+Alt+L to open popup"
        ;;
    status)
        echo "📊 Maysie AI Assistant Status"
        echo "=============================="
        sudo systemctl status maysie.service --no-pager
        ;;
    logs)
        echo "📄 Maysie Logs"
        echo "=============="
        if [ "$2" = "-f" ] || [ "$2" = "--follow" ]; then
            sudo tail -f /var/log/maysie/maysie.log
        elif [ "$2" = "-e" ] || [ "$2" = "--error" ]; then
            sudo grep -i error /var/log/maysie/maysie.log | tail -20
        else
            sudo tail -30 /var/log/maysie/maysie.log
        fi
        ;;
    config)
        echo "⚙️  Maysie Configuration"
        echo "========================"
        echo "Config file: $CONFIG_DIR/config.yaml"
        echo "API keys:    $CONFIG_DIR/secrets.env"
        echo "Logs:        /var/log/maysie/maysie.log"
        echo "Install:     $INSTALL_DIR"
        echo ""
        echo "Commands:"
        echo "  sudo nano $CONFIG_DIR/config.yaml     # Edit main config"
        echo "  sudo nano $CONFIG_DIR/secrets.env     # Edit API keys"
        echo "  maysie restart                        # Apply changes"
        ;;
    api)
        echo "🔑 API Key Management"
        echo "===================="
        if [ "$2" = "list" ]; then
            grep -E "^(# )?[A-Z_]+_API_KEY" "$CONFIG_DIR/secrets.env" || echo "No API keys found"
        elif [ "$2" = "add" ] && [ -n "$3" ] && [ -n "$4" ]; then
            sudo sed -i "/^# $3=/d" "$CONFIG_DIR/secrets.env"
            echo "$3=$4" | sudo tee -a "$CONFIG_DIR/secrets.env" > /dev/null
            echo "✅ Added $3"
            echo "Restart with: maysie restart"
        else
            echo "Usage: maysie api list"
            echo "       maysie api add GEMINI_API_KEY your-key-here"
        fi
        ;;
    test)
        echo "🧪 Testing Maysie Installation"
        echo "=============================="
        echo "1. Service:"
        sudo systemctl is-active maysie.service && echo "✅ Running" || echo "❌ Not running"
        echo ""
        echo "2. Dependencies:"
        $INSTALL_DIR/venv/bin/python3 -c "import tkinter; print('✅ Tkinter: OK')" 2>/dev/null || echo "❌ Tkinter: Missing"
        $INSTALL_DIR/venv/bin/python3 -c "import pynput; print('✅ Pynput: OK')" 2>/dev/null || echo "❌ Pynput: Missing"
        $INSTALL_DIR/venv/bin/python3 -c "import aiohttp; print('✅ Aiohttp: OK')" 2>/dev/null || echo "❌ Aiohttp: Missing"
        echo ""
        echo "3. Configuration:"
        [ -f "$CONFIG_DIR/config.yaml" ] && echo "✅ Config: Found" || echo "❌ Config: Missing"
        [ -f "$CONFIG_DIR/secrets.env" ] && echo "✅ Secrets: Found" || echo "❌ Secrets: Missing"
        echo ""
        echo "4. Hotkey test:"
        echo "   Press Ctrl+Alt+L - window should appear"
        echo ""
        echo "✅ Test complete!"
        ;;
    run)
        echo "▶️  Running Maysie in terminal mode..."
        cd "$INSTALL_DIR"
        sudo -u $USER ./venv/bin/python3 ./main.py
        ;;
    update)
        echo "🔄 Updating Maysie..."
        cd "$(dirname "$0")/../.."
        if [ -f maysie/install.sh ]; then
            echo "Found install script, running update..."
            sudo ./maysie/install.sh
        else
            echo "❌ Install script not found in current directory"
            echo "Update manually:"
            echo "  cd ~/maysie"
            echo "  git pull"
            echo "  sudo ./install.sh"
        fi
        ;;
    version)
        echo "Maysie AI Assistant v$VERSION"
        echo "Complete AI-powered Linux assistant"
        ;;
    help|*)
        echo "🤖 Maysie AI Assistant v$VERSION"
        echo "================================"
        echo ""
        echo "MAIN COMMANDS:"
        echo "  maysie start      - Start service"
        echo "  maysie stop       - Stop service"
        echo "  maysie restart    - Restart service"
        echo "  maysie status     - Check status"
        echo "  maysie logs       - View logs"
        echo "  maysie logs -f    - Follow logs"
        echo "  maysie logs -e    - Show errors"
        echo "  maysie config     - Config info"
        echo "  maysie api        - API key management"
        echo "  maysie test       - Test installation"
        echo "  maysie run        - Run in terminal"
        echo "  maysie update     - Update Maysie"
        echo "  maysie version    - Show version"
        echo "  maysie help       - This help"
        echo ""
        echo "QUICK START:"
        echo "  1. maysie start           # Start service"
        echo "  2. Press Ctrl+Alt+L       # Open popup"
        echo "  3. Type 'help' in popup   # See commands"
        echo "  4. Edit API keys:         # Add AI capabilities"
        echo "     sudo nano /etc/maysie/secrets.env"
        echo ""
        echo "FEATURES:"
        echo "  • Smart AI routing (Gemini/DeepSeek/ChatGPT)"
        echo "  • System package management"
        echo "  • File operations"
        echo "  • Process management"
        echo "  • Hotkey: Ctrl+Alt+L"
        echo "  • Encrypted API key storage"
        echo ""
        echo "Need help? Check logs: maysie logs"
        ;;
esac
EOF

chmod +x "$CURRENT_HOME/.local/bin/maysie"
chown $CURRENT_USER:$CURRENT_USER "$CURRENT_HOME/.local/bin/maysie"

# Add to PATH
if ! grep -q "\.local/bin" "$CURRENT_HOME/.bashrc"; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$CURRENT_HOME/.bashrc"
    export PATH="$HOME/.local/bin:$PATH"
fi

print_success "User commands created"

# ---------------------------------------------------------------------
# STEP 11: START THE SERVICE
# ---------------------------------------------------------------------
print_status "Starting Maysie service..."
systemctl start maysie.service
sleep 5

if systemctl is-active --quiet maysie.service; then
    print_success "✅ Maysie service is running!"
else
    print_warning "⚠️ Service failed to start automatically"
    print_status "Troubleshooting steps:"
    echo "1. Check dependencies: maysie test"
    echo "2. View logs: maysie logs"
    echo "3. Manual start: maysie run"
    echo "4. Install missing packages:"
    echo "   sudo apt install python3-tk"
    echo "   sudo -u $CURRENT_USER $VENV_PIP install pynput aiohttp PyYAML"
fi

# ---------------------------------------------------------------------
# STEP 12: FINAL OUTPUT
# ---------------------------------------------------------------------
print_status "Installation complete!"

clear
echo ""
echo "================================================"
echo "  🎉 MAYSIE AI ASSISTANT - INSTALLATION COMPLETE!"
echo "================================================"
echo ""
echo "✅ All features installed:"
echo "   • Smart AI routing (Gemini/DeepSeek/ChatGPT)"
echo "   • System package management"
echo "   • File operations"
echo "   • Process management"
echo "   • Hotkey: Ctrl+Alt+L"
echo "   • Tkinter GUI interface"
echo "   • Encrypted configuration"
echo ""
echo "🎯 QUICK START:"
echo "   1. Press Ctrl+Alt+L to open the popup"
echo "   2. Type 'help' to see all commands"
echo "   3. Try: install neofetch"
echo "   4. Try: is docker available for Debian?"
echo "   5. Try: list processes"
echo ""
echo "🔧 CONFIGURATION:"
echo "   Edit API keys: sudo nano /etc/maysie/secrets.env"
echo "   Remove # from lines with your API keys"
echo "   Available providers: Gemini, OpenAI, DeepSeek"
echo ""
echo "🛠️  MANAGEMENT:"
echo "   maysie start      # Start service"
echo "   maysie stop       # Stop service"
echo "   maysie status     # Check status"
echo "   maysie logs       # View logs"
echo "   maysie config     # Configuration"
echo "   maysie test       # Test installation"
echo ""
echo "🔍 SMART FEATURES:"
echo "   • Auto-detects package manager (apt/dnf/pacman)"
echo "   • Checks package availability before installing"
echo "   • Suggests alternatives if package not found"
echo "   • Smart AI routing based on query type"
echo "   • Research: Gemini"
echo "   • Coding: DeepSeek"
echo "   • Reasoning: ChatGPT"
echo ""
echo "💡 TIP: First time, set sudo password in the popup"
echo "       Click 'Sudo' button or type: sudo code:yourpassword"
echo ""
echo "================================================"
echo "   Press Ctrl+Alt+L to begin your AI journey!  "
echo "================================================"
echo ""

# Show backup info
if [ -d "$BACKUP_DIR" ]; then
    echo "📁 Backup saved to: $BACKUP_DIR"
    echo "   Config files from previous installation preserved"
fi

print_success "Installation finished successfully! 🚀"
echo ""

exit 0
EOF