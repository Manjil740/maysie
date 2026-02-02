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