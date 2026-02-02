"""
Global hotkey listener
Listens for hotkey combination and signals main service.
"""

import threading
import socket
from pynput import keyboard
from pynput.keyboard import Key, KeyCode

from maysie.utils.logger import get_logger
from maysie.config import get_config

logger = get_logger(__name__)


class HotkeyListener:
    """Listens for global hotkey and signals service"""
    
    def __init__(self, signal_port: int = 9999):
        """
        Initialize hotkey listener.
        
        Args:
            signal_port: Port to signal main service
        """
        self.config = get_config()
        self.signal_port = signal_port
        self.current_keys = set()
        self.hotkey_combo = self._parse_hotkey()
        self.listener = None
        self.running = False
    
    def _parse_hotkey(self) -> set:
        """Parse hotkey combination from config"""
        combo_str = self.config.hotkey.combination
        keys = set()
        
        # Parse: "Super+Alt+A" → {Key.cmd, Key.alt, 'a'}
        for part in combo_str.split('+'):
            part = part.strip().lower()
            if part == 'super' or part == 'cmd' or part == 'win':
                keys.add(Key.cmd)
            elif part == 'ctrl' or part == 'control':
                keys.add(Key.ctrl)
            elif part == 'alt':
                keys.add(Key.alt)
            elif part == 'shift':
                keys.add(Key.shift)
            else:
                keys.add(part)
        
        logger.info(f"Hotkey combination: {combo_str}")
        return keys
    
    def start(self):
        """Start listening for hotkey"""
        if self.running:
            return
        
        self.running = True
        self.listener = keyboard.Listener(
            on_press=self._on_press,
            on_release=self._on_release
        )
        self.listener.start()
        logger.info("Hotkey listener started")
    
    def stop(self):
        """Stop listening"""
        if self.listener:
            self.running = False
            self.listener.stop()
            logger.info("Hotkey listener stopped")
    
    def _on_press(self, key):
        """Handle key press"""
        try:
            # Normalize key
            if hasattr(key, 'char') and key.char:
                key_norm = key.char.lower()
            else:
                key_norm = key
            
            self.current_keys.add(key_norm)
            
            # Check if hotkey combo is pressed
            if self._is_hotkey_pressed():
                logger.info("Hotkey detected!")
                self._signal_service()
                # Clear keys to prevent repeated signals
                self.current_keys.clear()
        
        except Exception as e:
            logger.error(f"Hotkey press error: {e}")
    
    def _on_release(self, key):
        """Handle key release"""
        try:
            if hasattr(key, 'char') and key.char:
                key_norm = key.char.lower()
            else:
                key_norm = key
            
            self.current_keys.discard(key_norm)
        
        except Exception as e:
            logger.error(f"Hotkey release error: {e}")
    
    def _is_hotkey_pressed(self) -> bool:
        """Check if hotkey combination is currently pressed"""
        # Check if all required keys are pressed
        for key in self.hotkey_combo:
            if key not in self.current_keys:
                return False
        return True
    
    def _signal_service(self):
        """Signal main service that hotkey was pressed"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.connect(('127.0.0.1', self.signal_port))
                sock.sendall(b'HOTKEY_PRESSED\n')
        except Exception as e:
            logger.error(f"Failed to signal service: {e}")