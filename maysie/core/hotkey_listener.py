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
    
    def _parse_hotkey(self) -> list:
        """Parse hotkey combination from config"""
        combo_str = self.config.get('hotkey.combination', 'ctrl+alt+l')
        keys = []
        
        # Parse: "ctrl+alt+l" → ['ctrl', 'alt', 'l']
        for part in combo_str.lower().split('+'):
            part = part.strip()
            keys.append(part)
        
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
            self.listener.join(timeout=1)
            logger.info("Hotkey listener stopped")
    
    def _on_press(self, key):
        """Handle key press"""
        try:
            key_str = self._key_to_string(key)
            if key_str:
                self.current_keys.add(key_str)
            
            # Check if all keys in combo are pressed
            if self._is_hotkey_pressed():
                logger.info("Hotkey detected!")
                self._signal_service()
                # Clear current keys to avoid repeated signals
                self.current_keys.clear()
        
        except Exception as e:
            logger.error(f"Hotkey press error: {e}")
    
    def _on_release(self, key):
        """Handle key release"""
        try:
            key_str = self._key_to_string(key)
            if key_str in self.current_keys:
                self.current_keys.remove(key_str)
        except Exception as e:
            logger.error(f"Hotkey release error: {e}")
    
    def _key_to_string(self, key):
        """Convert key to string representation"""
        if hasattr(key, 'char') and key.char:
            return key.char.lower()
        elif hasattr(key, 'name'):
            return key.name.lower()
        else:
            return str(key).lower().replace("'", "")
    
    def _is_hotkey_pressed(self) -> bool:
        """Check if hotkey combination is currently pressed"""
        # All keys in combo must be in current_keys
        for key in self.hotkey_combo:
            if key not in self.current_keys:
                return False
        
        # Check if exactly these keys are pressed (no extra keys)
        return len(self.current_keys) == len(self.hotkey_combo)
    
    def _signal_service(self):
        """Signal main service that hotkey was pressed"""
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
                sock.connect(('127.0.0.1', self.signal_port))
                sock.sendall(b'HOTKEY_PRESSED\n')
                logger.debug("Hotkey signal sent to service")
        except ConnectionRefusedError:
            logger.warning("Maysie service not responding")
        except Exception as e:
            logger.error(f"Failed to signal service: {e}")