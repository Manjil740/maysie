"""
Command routing and intent classification
Routes commands to appropriate handlers (system vs AI) and selects best AI provider.
"""

import re
import asyncio
from typing import Optional, Dict, Any, Tuple
from pathlib import Path

from maysie.utils.logger import get_logger
from maysie.utils.security import CredentialStore, get_security_manager
from maysie.config import get_config
from maysie.ai import GeminiProvider, ChatGPTProvider, DeepSeekProvider
from maysie.system import (
    get_package_manager, 
    get_file_operations, 
    get_process_manager,
    get_sudo_handler
)

logger = get_logger(__name__)


class CommandRouter:
    """Routes commands to appropriate handlers and AI providers"""
    
    def __init__(self):
        """Initialize command router"""
        self.config = get_config()
        self.sudo_handler = get_sudo_handler()
        self.pkg_manager = get_package_manager()
        self.file_ops = get_file_operations()
        self.process_mgr = get_process_manager()
        
        # Initialize AI providers
        self._load_ai_providers()
    
    def _load_ai_providers(self):
        """Load and initialize AI providers"""
        credential_store = CredentialStore(
            Path('/etc/maysie/api_keys.enc'),
            get_security_manager()
        )
        
        self.ai_providers = {
            'gemini': GeminiProvider(api_key=credential_store.get('gemini_api_key')),
            'chatgpt': ChatGPTProvider(api_key=credential_store.get('openai_api_key')),
            'deepseek': DeepSeekProvider(api_key=credential_store.get('deepseek_api_key')),
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
            # Parse special commands first
            if command.startswith('sudo code:'):
                return self._handle_sudo_code(command)
            
            if command.startswith('enter debug mode'):
                return self._handle_debug_mode(command)
            
            if command.startswith('respond '):
                return await self._handle_styled_response(command)
            
            # Check for system commands
            intent = self._classify_intent(command)
            
            if intent['type'] == 'system':
                return self._handle_system_command(command, intent)
            else:
                # Route to AI
                return await self._handle_ai_query(command, intent)
        
        except Exception as e:
            logger.error(f"Command routing failed: {e}")
            return f"Error: {e}"
    
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
            'package_install': r'\b(install|setup)\s+([a-zA-Z0-9\-_\s]+)',
            'package_uninstall': r'\b(uninstall|remove)\s+([a-zA-Z0-9\-_\s]+)',
            'package_update': r'\b(update|upgrade)\s+(system|packages?)',
            'file_create': r'\bcreate\s+(file|folder|directory)\s+(.+)',
            'file_move': r'\bmove\s+(.+?)\s+to\s+(.+)',
            'file_delete': r'\bdelete\s+(file|folder)?\s*(.+)',
            'file_find': r'\bfind\s+(.+?)\s+in\s+(.+)',
            'file_list': r'\blist\s+(.+)',
            'process_kill': r'\bkill\s+(.+)',
            'process_list': r'\blist\s+(all\s+)?processes?\s*(.+)?',
            'app_launch': r'\b(launch|open|start)\s+(.+)',
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
                return "Invalid syntax. Use: sudo code:<password> [-t <minutes>]"
            
            password = parts[1][5:]  # Remove 'code:' prefix
            
            # Check for timeout flag
            timeout = None
            if len(parts) > 2 and parts[2] == '-t' and len(parts) > 3:
                try:
                    timeout = int(parts[3]) * 60  # Convert minutes to seconds
                except ValueError:
                    return "Invalid timeout value"
            
            self.sudo_handler.set_password(password, timeout)
            
            timeout_msg = f" for {timeout//60} minutes" if timeout else ""
            return f"✓ Sudo credentials cached{timeout_msg}"
            
        except ValueError as e:
            return f"✗ {e}"
        except Exception as e:
            logger.error(f"Sudo code handling failed: {e}")
            return f"✗ Failed to cache credentials: {e}"
    
    def _handle_debug_mode(self, command: str) -> str:
        """Handle 'enter debug mode <password>' command"""
        try:
            parts = command.split(maxsplit=3)
            if len(parts) < 4:
                return "Usage: enter debug mode <password>"
            
            password = parts[3]
            
            # Validate sudo password
            if not self.sudo_handler._validate_password(password):
                return "✗ Invalid password"
            
            # Set password and return web UI URL
            self.sudo_handler.set_password(password, 3600)  # 1 hour for debug mode
            
            # Signal web UI to start (handled by main service)
            return "DEBUG_MODE_ACTIVATED"
            
        except Exception as e:
            logger.error(f"Debug mode activation failed: {e}")
            return f"✗ Failed to enter debug mode: {e}"
    
    async def _handle_styled_response(self, command: str) -> str:
        """Handle 'respond <style>: <query>' command"""
        try:
            # Parse: respond short: what is kubernetes
            match = re.match(r'respond\s+(\w+):\s*(.+)', command, re.IGNORECASE)
            if not match:
                return "Invalid syntax. Use: respond <style>: <query>"
            
            style, query = match.groups()
            
            # Get style instruction
            style_instruction = self.config.response.styles.get(
                style.lower(),
                self.config.response.styles.get(self.config.response.default_style)
            )
            
            # Route to AI with style context
            intent = self._classify_intent(query)
            context = {'response_style': style_instruction}
            
            if intent['type'] == 'ai':
                provider = self.ai_providers[intent['provider']]
                return await provider.query(query, context)
            else:
                return "Style commands only work with AI queries"
                
        except Exception as e:
            logger.error(f"Styled response handling failed: {e}")
            return f"Error: {e}"
    
    def _handle_system_command(self, command: str, intent: Dict) -> str:
        """Handle system commands"""
        subtype = intent['subtype']
        matches = intent['matches']
        
        try:
            if subtype == 'package_install':
                packages = matches[1].strip().split()
                success, msg = self.pkg_manager.install(packages)
                return f"{'✓' if success else '✗'} {msg}"
            
            elif subtype == 'package_uninstall':
                packages = matches[1].strip().split()
                success, msg = self.pkg_manager.uninstall(packages)
                return f"{'✓' if success else '✗'} {msg}"
            
            elif subtype == 'package_update':
                success, msg = self.pkg_manager.update()
                return f"{'✓' if success else '✗'} {msg}"
            
            elif subtype == 'file_create':
                file_type = matches[0]
                path = matches[1].strip()
                if 'folder' in file_type or 'directory' in file_type:
                    success, msg = self.file_ops.create_directory(path)
                else:
                    # Create empty file
                    Path(path).touch()
                    success, msg = True, f"File created: {path}"
                return f"{'✓' if success else '✗'} {msg}"
            
            elif subtype == 'file_move':
                source = matches[0].strip()
                dest = matches[1].strip()
                success, msg = self.file_ops.move_file(source, dest)
                return f"{'✓' if success else '✗'} {msg}"
            
            elif subtype == 'file_delete':
                path = matches[1].strip()
                if Path(path).is_dir():
                    success, msg = self.file_ops.delete_directory(path, recursive=True)
                else:
                    success, msg = self.file_ops.delete_file(path)
                return f"{'✓' if success else '✗'} {msg}"
            
            elif subtype == 'process_kill':
                target = matches[0].strip()
                success, msg = self.process_mgr.kill_by_name(target)
                return f"{'✓' if success else '✗'} {msg}"
            
            elif subtype == 'process_list':
                filter_name = matches[1].strip() if matches[1] else None
                processes = self.process_mgr.list_processes(filter_name)
                if processes:
                    output = "\n".join([
                        f"PID {p['pid']}: {p['name']} - CPU: {p['cpu']}, Mem: {p['memory']}"
                        for p in processes[:10]  # Limit to 10
                    ])
                    return f"Processes:\n{output}"
                else:
                    return "No matching processes found"
            
            elif subtype == 'app_launch':
                app_name = matches[1].strip()
                success, msg = self.process_mgr.launch_application(app_name)
                return f"{'✓' if success else '✗'} {msg}"
            
            else:
                return f"System command not implemented: {subtype}"
        
        except Exception as e:
            logger.error(f"System command execution failed: {e}")
            return f"✗ Error: {e}"
    
    async def _handle_ai_query(self, command: str, intent: Dict) -> str:
        """Handle AI queries"""
        provider_name = intent['provider']
        provider = self.ai_providers.get(provider_name)
        
        if not provider:
            return f"AI provider '{provider_name}' not available"
        
        if not provider.is_configured():
            return f"AI provider '{provider_name}' not configured. Add API key in debug mode."
        
        try:
            # Get response style
            style_instruction = self.config.response.styles.get(
                self.config.response.default_style,
                "Provide a clear, helpful response."
            )
            
            context = {'response_style': style_instruction}
            response = await provider.query(command, context)
            return response
            
        except Exception as e:
            logger.error(f"AI query failed: {e}")
            return f"✗ AI query failed: {e}"


# Global instance
_global_router: Optional[CommandRouter] = None


def get_command_router() -> CommandRouter:
    """Get global command router instance"""
    global _global_router
    if _global_router is None:
        _global_router = CommandRouter()
    return _global_router