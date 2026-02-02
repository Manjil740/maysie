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