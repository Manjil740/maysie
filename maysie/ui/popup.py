"""
GTK popup UI
Small bottom-right popup for command input.
"""

import gi
gi.require_version('Gtk', '3.0')
from gi.repository import Gtk, Gdk, GLib
import threading
import asyncio

from maysie.utils.logger import get_logger
from maysie.config import get_config

logger = get_logger(__name__)


class PopupWindow(Gtk.Window):
    """Popup window for command input"""
    
    def __init__(self, on_submit_callback):
        """
        Initialize popup window.
        
        Args:
            on_submit_callback: Callback function for command submission
        """
        super().__init__(title="Maysie")
        self.config = get_config()
        self.on_submit_callback = on_submit_callback
        
        self.set_default_size(
            self.config.ui.width,
            self.config.ui.height
        )
        self.set_decorated(True)
        self.set_keep_above(True)
        self.set_skip_taskbar_hint(True)
        self.set_opacity(self.config.ui.opacity)
        
        # Position window
        self._position_window()
        
        # Create UI
        self._create_ui()
        
        # Connect signals
        self.connect("delete-event", self._on_close)
        self.connect("key-press-event", self._on_key_press)
    
    def _position_window(self):
        """Position window according to config"""
        screen = Gdk.Screen.get_default()
        screen_width = screen.get_width()
        screen_height = screen.get_height()
        
        position = self.config.ui.position
        
        if position == "bottom-right":
            x = screen_width - self.config.ui.width - 20
            y = screen_height - self.config.ui.height - 60
        elif position == "bottom-left":
            x = 20
            y = screen_height - self.config.ui.height - 60
        elif position == "top-right":
            x = screen_width - self.config.ui.width - 20
            y = 60
        elif position == "top-left":
            x = 20
            y = 60
        else:
            x = (screen_width - self.config.ui.width) // 2
            y = (screen_height - self.config.ui.height) // 2
        
        self.move(x, y)
    
    def _create_ui(self):
        """Create UI elements"""
        vbox = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        vbox.set_margin_top(10)
        vbox.set_margin_bottom(10)
        vbox.set_margin_start(10)
        vbox.set_margin_end(10)
        
        # Input row
        input_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        
        # Text entry
        self.entry = Gtk.Entry()
        self.entry.set_placeholder_text("Enter command...")
        self.entry.connect("activate", self._on_submit)
        input_box.pack_start(self.entry, True, True, 0)
        
        # Submit button
        submit_btn = Gtk.Button(label="Submit")
        submit_btn.connect("clicked", self._on_submit)
        input_box.pack_start(submit_btn, False, False, 0)
        
        # Close button
        close_btn = Gtk.Button(label="×")
        close_btn.connect("clicked", self._on_close)
        input_box.pack_start(close_btn, False, False, 0)
        
        vbox.pack_start(input_box, False, False, 0)
        
        # Status label
        self.status_label = Gtk.Label(label="Ready")
        self.status_label.set_halign(Gtk.Align.START)
        vbox.pack_start(self.status_label, False, False, 0)
        
        self.add(vbox)
    
    def _on_key_press(self, widget, event):
        """Handle key press (Escape to close)"""
        if event.keyval == Gdk.KEY_Escape:
            self.hide()
            return True
        return False
    
    def _on_submit(self, widget):
        """Handle command submission"""
        command = self.entry.get_text().strip()
        if not command:
            return
        
        self.entry.set_text("")
        self.set_status("Processing...")
        
        # Run callback in thread
        threading.Thread(
            target=self._submit_command,
            args=(command,),
            daemon=True
        ).start()
    
    def _submit_command(self, command: str):
        """Submit command (runs in thread)"""
        try:
            # Create event loop for async call
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            
            result = loop.run_until_complete(self.on_submit_callback(command))
            
            loop.close()
            
            # Update UI in main thread
            GLib.idle_add(self._show_result, result)
        
        except Exception as e:
            logger.error(f"Command submission failed: {e}")
            GLib.idle_add(self._show_result, f"Error: {e}")
    
    def _show_result(self, result: str):
        """Show result and auto-hide"""
        # Truncate long results
        if len(result) > 200:
            result = result[:200] + "..."
        
        self.set_status(result)
        
        # Auto-hide after delay
        if self.config.ui.auto_hide_delay > 0:
            GLib.timeout_add_seconds(
                self.config.ui.auto_hide_delay,
                self.hide
            )
        
        return False  # Don't repeat
    
    def set_status(self, text: str):
        """Update status label"""
        self.status_label.set_markup(f"<small>{text}</small>")
    
    def _on_close(self, widget, event=None):
        """Handle window close"""
        self.hide()
        return True  # Don't destroy, just hide
    
    def show_and_focus(self):
        """Show window and focus input"""
        self.show_all()
        self.present()
        self.entry.grab_focus()


class PopupUI:
    """Manages popup UI lifecycle"""
    
    def __init__(self, on_submit_callback):
        """
        Initialize popup UI manager.
        
        Args:
            on_submit_callback: Async callback for command submission
        """
        self.on_submit_callback = on_submit_callback
        self.window = None
        self.gtk_thread = None
    
    def start(self):
        """Start GTK main loop in thread"""
        def run_gtk():
            self.window = PopupWindow(self.on_submit_callback)
            Gtk.main()
        
        self.gtk_thread = threading.Thread(target=run_gtk, daemon=True)
        self.gtk_thread.start()
        logger.info("Popup UI started")
    
    def show(self):
        """Show popup window"""
        if self.window:
            GLib.idle_add(self.window.show_and_focus)
    
    def stop(self):
        """Stop GTK main loop"""
        if Gtk.main_level() > 0:
            Gtk.main_quit()