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
    combination: str = "Super+Alt+A"
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
                {"pattern": "research|latest|news|current", "provider": "gemini", "priority": 10},
                {"pattern": "code|script|program|debug|function", "provider": "deepseek", "priority": 10},
                {"pattern": "decide|compare|analyze|recommend|choose", "provider": "chatgpt", "priority": 10},
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
    width: int = 400
    height: int = 150
    opacity: float = 0.95


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
                "bullets": "Provide answer as clear bullet points.",
                "technical": "Provide detailed technical explanation with proper terminology.",
            }


@dataclass
class LoggingConfig:
    """Logging configuration"""
    level: str = "INFO"
    max_file_size_mb: int = 10
    backup_count: int = 5
    enable_debug: bool = False


@dataclass
class WebUIConfig:
    """Web UI configuration"""
    enabled: bool = True
    host: str = "127.0.0.1"
    port: int = 7777
    auth_required: bool = True


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
        self.web_ui = WebUIConfig()
        
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
                if 'web_ui' in data:
                    self.web_ui = WebUIConfig(**data['web_ui'])
                
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
                'web_ui': asdict(self.web_ui),
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