"""
Command execution engine
Executes routed commands and handles AI query execution.
"""

import subprocess
import asyncio
from typing import Optional, Dict, Any
from pathlib import Path
from maysie.utils.logger import get_logger

logger = get_logger(__name__)

class CommandExecutor:
    """Executes commands after routing"""
    
    def __init__(self):
        """Initialize executor"""
        pass
    
    async def execute_system_command(self, cmd: str, context: Dict[str, Any]) -> str:
        """Execute system command"""
        try:
            result = await asyncio.create_subprocess_shell(
                cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await result.communicate()
            if result.returncode != 0:
                return f"Error: {stderr.decode()}"
            return stdout.decode()
        except Exception as e:
            logger.error(f"System command execution failed: {e}")
            raise
    
    async def execute_ai_query(self, provider, prompt: str, context: Optional[Dict[str, Any]] = None) -> str:
        """Execute AI query through provider"""
        try:
            response = await provider.query(prompt, context)
            return response
        except Exception as e:
            logger.error(f"AI query execution failed: {e}")
            raise

# Global executor instance
_global_executor: Optional[CommandExecutor] = None

def get_executor() -> CommandExecutor:
    """Get global executor instance"""
    global _global_executor
    if _global_executor is None:
        _global_executor = CommandExecutor()
    return _global_executor