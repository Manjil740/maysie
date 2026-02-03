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