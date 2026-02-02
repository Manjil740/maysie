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