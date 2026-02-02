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