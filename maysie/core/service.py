"""
Maysie main service daemon
Coordinates all components and handles the main event loop.
"""

import asyncio
import socket
import signal
import sys
import threading
from pathlib import Path

from maysie.utils.logger import get_logger
from maysie.config import get_config
from maysie.core.hotkey_listener import HotkeyListener
from maysie.core.command_router import get_command_router
from maysie.ui.popup import PopupUI

logger = get_logger(__name__)


class MaysieService:
    """Main Maysie service"""
    
    def __init__(self):
        """Initialize service"""
        self.config = get_config()
        self.running = False
        self.signal_port = 9999
        self.signal_socket = None
        
        # Components
        self.hotkey_listener = None
        self.popup_ui = None
        self.command_router = None
        
        # Web UI (lazy loaded)
        self.web_ui = None
    
    async def start(self):
        """Start all service components"""
        logger.info("Starting Maysie service...")
        
        try:
            # Initialize command router
            self.command_router = get_command_router()
            
            # Initialize popup UI
            self.popup_ui = PopupUI(self._handle_command)
            self.popup_ui.start()
            
            # Start signal listener socket
            await self._start_signal_listener()
            
            # Start hotkey listener
            self.hotkey_listener = HotkeyListener(self.signal_port)
            self.hotkey_listener.start()
            
            # Setup signal handlers
            signal.signal(signal.SIGTERM, self._signal_handler)
            signal.signal(signal.SIGINT, self._signal_handler)
            
            self.running = True
            logger.info("✓ Maysie service started successfully")
            
            # Main event loop
            await self._main_loop()
        
        except Exception as e:
            logger.error(f"Failed to start service: {e}")
            await self.stop()
            raise
    
    async def _start_signal_listener(self):
        """Start socket listener for hotkey signals"""
        self.signal_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.signal_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.signal_socket.bind(('127.0.0.1', self.signal_port))
        self.signal_socket.listen(5)
        self.signal_socket.setblocking(False)
        
        logger.info(f"Signal listener on port {self.signal_port}")
    
    async def _main_loop(self):
        """Main event loop"""
        loop = asyncio.get_event_loop()
        
        while self.running:
            try:
                # Wait for signals with timeout
                await asyncio.wait_for(
                    loop.sock_accept(self.signal_socket),
                    timeout=1.0
                )
                
                # Hotkey was pressed
                logger.debug("Hotkey signal received")
                self._show_popup()
            
            except asyncio.TimeoutError:
                # No signal, continue
                continue
            except Exception as e:
                logger.error(f"Main loop error: {e}")
                await asyncio.sleep(1)
    
    def _show_popup(self):
        """Show popup window"""
        if self.popup_ui:
            self.popup_ui.show()
    
    async def _handle_command(self, command: str) -> str:
        """
        Handle command from popup UI.
        
        Args:
            command: User command
            
        Returns:
            Response string
        """
        logger.info(f"Processing command: {command[:50]}...")
        
        try:
            # Check for debug mode activation
            if command.startswith('enter debug mode'):
                response = await self.command_router.route_command(command)
                if response == "DEBUG_MODE_ACTIVATED":
                    # Start web UI
                    self._start_web_ui()
                    return "✓ Debug mode activated. Opening http://localhost:7777"
                return response
            
            # Route command
            response = await self.command_router.route_command(command)
            return response
        
        except Exception as e:
            logger.error(f"Command handling failed: {e}")
            return f"Error: {e}"
    
    def _start_web_ui(self):
        """Start web UI (lazy loaded)"""
        if self.web_ui is None:
            try:
                from maysie.ui.debug_web import DebugWebUI
                self.web_ui = DebugWebUI()
                
                # Start in thread
                threading.Thread(
                    target=self.web_ui.start,
                    daemon=True
                ).start()
                
                logger.info("Web UI started")
            except Exception as e:
                logger.error(f"Failed to start web UI: {e}")
    
    def _signal_handler(self, signum, frame):
        """Handle termination signals"""
        logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
    
    async def stop(self):
        """Stop all service components"""
        logger.info("Stopping Maysie service...")
        
        self.running = False
        
        # Stop hotkey listener
        if self.hotkey_listener:
            self.hotkey_listener.stop()
        
        # Stop popup UI
        if self.popup_ui:
            self.popup_ui.stop()
        
        # Close signal socket
        if self.signal_socket:
            self.signal_socket.close()
        
        # Stop web UI
        if self.web_ui:
            self.web_ui.stop()
        
        logger.info("✓ Maysie service stopped")


async def main():
    """Main entry point"""
    # Setup logging
    import logging
    from maysie.utils.logger import MaysieLogger
    
    # Check for debug flag
    debug = '--debug' in sys.argv
    if debug:
        MaysieLogger.set_level(logging.DEBUG)
        logger.info("Debug mode enabled")
    
    # Create and start service
    service = MaysieService()
    
    try:
        await service.start()
    except KeyboardInterrupt:
        logger.info("Keyboard interrupt received")
    finally:
        await service.stop()


if __name__ == '__main__':
    asyncio.run(main())