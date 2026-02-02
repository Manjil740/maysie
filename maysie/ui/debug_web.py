"""
Debug/Configuration Web UI
Flask-based interface for Maysie configuration.
"""

from flask import Flask, render_template_string, request, jsonify
from pathlib import Path
import webbrowser

from maysie.utils.logger import get_logger
from maysie.config import get_config, reload_config
from maysie.utils.security import CredentialStore, get_security_manager

logger = get_logger(__name__)

# Simple HTML template
HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>Maysie Debug UI</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #1e1e1e; color: #fff; }
        h1 { color: #4CAF50; }
        .section { margin: 20px 0; padding: 15px; background: #2d2d2d; border-radius: 5px; }
        input, select, textarea { padding: 8px; margin: 5px 0; width: 100%; background: #3d3d3d; color: #fff; border: 1px solid #555; }
        button { padding: 10px 20px; background: #4CAF50; color: white; border: none; cursor: pointer; margin: 5px; }
        button:hover { background: #45a049; }
        .log { background: #1a1a1a; padding: 10px; font-family: monospace; font-size: 12px; max-height: 300px; overflow-y: scroll; }
        .success { color: #4CAF50; }
        .error { color: #f44336; }
    </style>
</head>
<body>
    <h1>🤖 Maysie Debug Interface</h1>
    
    <div class="section">
        <h2>Hotkey Configuration</h2>
        <input type="text" id="hotkey" placeholder="e.g., Super+Alt+A" value="{{ config.hotkey.combination }}">
        <button onclick="saveHotkey()">Save Hotkey</button>
    </div>
    
    <div class="section">
        <h2>AI Providers</h2>
        <p>Configure API keys for AI providers:</p>
        <label>Gemini API Key:</label>
        <input type="password" id="gemini_key" placeholder="Enter Gemini API key">
        <label>OpenAI API Key:</label>
        <input type="password" id="openai_key" placeholder="Enter OpenAI API key">
        <label>DeepSeek API Key:</label>
        <input type="password" id="deepseek_key" placeholder="Enter DeepSeek API key">
        <button onclick="saveAPIKeys()">Save API Keys</button>
    </div>
    
    <div class="section">
        <h2>Response Style</h2>
        <select id="response_style">
            <option value="short" {{ 'selected' if config.response.default_style == 'short' }}>Short</option>
            <option value="detailed" {{ 'selected' if config.response.default_style == 'detailed' }}>Detailed</option>
            <option value="bullets" {{ 'selected' if config.response.default_style == 'bullets' }}>Bullets</option>
            <option value="technical" {{ 'selected' if config.response.default_style == 'technical' }}>Technical</option>
        </select>
        <button onclick="saveResponseStyle()">Save Style</button>
    </div>
    
    <div class="section">
        <h2>System Logs</h2>
        <div class="log" id="logs">
            Loading logs...
        </div>
        <button onclick="refreshLogs()">Refresh Logs</button>
    </div>
    
    <div id="message"></div>
    
    <script>
        function showMessage(text, isError) {
            const msg = document.getElementById('message');
            msg.innerHTML = '<p class="' + (isError ? 'error' : 'success') + '">' + text + '</p>';
            setTimeout(() => msg.innerHTML = '', 3000);
        }
        
        function saveHotkey() {
            const hotkey = document.getElementById('hotkey').value;
            fetch('/api/config/hotkey', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({hotkey: hotkey})
            })
            .then(r => r.json())
            .then(data => showMessage(data.message, !data.success))
            .catch(e => showMessage('Error: ' + e, true));
        }
        
        function saveAPIKeys() {
            const keys = {
                gemini: document.getElementById('gemini_key').value,
                openai: document.getElementById('openai_key').value,
                deepseek: document.getElementById('deepseek_key').value
            };
            fetch('/api/config/api_keys', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify(keys)
            })
            .then(r => r.json())
            .then(data => showMessage(data.message, !data.success))
            .catch(e => showMessage('Error: ' + e, true));
        }
        
        function saveResponseStyle() {
            const style = document.getElementById('response_style').value;
            fetch('/api/config/response_style', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({style: style})
            })
            .then(r => r.json())
            .then(data => showMessage(data.message, !data.success))
            .catch(e => showMessage('Error: ' + e, true));
        }
        
        function refreshLogs() {
            fetch('/api/logs')
            .then(r => r.text())
            .then(data => document.getElementById('logs').innerText = data)
            .catch(e => showMessage('Error loading logs: ' + e, true));
        }
        
        // Auto-refresh logs every 5 seconds
        setInterval(refreshLogs, 5000);
        refreshLogs();
    </script>
</body>
</html>
"""


class DebugWebUI:
    """Flask-based debug web UI"""
    
    def __init__(self):
        """Initialize web UI"""
        self.app = Flask(__name__)
        self.config = get_config()
        self.credential_store = CredentialStore(
            Path('/etc/maysie/api_keys.enc'),
            get_security_manager()
        )
        self._setup_routes()
    
    def _setup_routes(self):
        """Setup Flask routes"""
        
        @self.app.route('/')
        def index():
            return render_template_string(HTML_TEMPLATE, config=self.config)
        
        @self.app.route('/api/config/hotkey', methods=['POST'])
        def set_hotkey():
            data = request.json
            self.config.hotkey.combination = data.get('hotkey', 'Super+Alt+A')
            self.config.save()
            return jsonify({'success': True, 'message': 'Hotkey updated. Restart required.'})
        
        @self.app.route('/api/config/api_keys', methods=['POST'])
        def set_api_keys():
            data = request.json
            if data.get('gemini'):
                self.credential_store.set('gemini_api_key', data['gemini'])
            if data.get('openai'):
                self.credential_store.set('openai_api_key', data['openai'])
            if data.get('deepseek'):
                self.credential_store.set('deepseek_api_key', data['deepseek'])
            return jsonify({'success': True, 'message': 'API keys saved'})
        
        @self.app.route('/api/config/response_style', methods=['POST'])
        def set_response_style():
            data = request.json
            self.config.response.default_style = data.get('style', 'short')
            self.config.save()
            return jsonify({'success': True, 'message': 'Response style updated'})
        
        @self.app.route('/api/logs')
        def get_logs():
            try:
                log_file = Path('/var/log/maysie/maysie.log')
                if log_file.exists():
                    # Return last 100 lines
                    with open(log_file, 'r') as f:
                        lines = f.readlines()
                        return ''.join(lines[-100:])
                return "No logs available"
            except Exception as e:
                return f"Error reading logs: {e}"
    
    def start(self):
        """Start Flask server"""
        try:
            # Open browser
            webbrowser.open(f'http://{self.config.web_ui.host}:{self.config.web_ui.port}')
            
            # Start server
            self.app.run(
                host=self.config.web_ui.host,
                port=self.config.web_ui.port,
                debug=False
            )
        except Exception as e:
            logger.error(f"Web UI failed to start: {e}")
    
    def stop(self):
        """Stop Flask server"""
        # Flask has no clean way to stop from code
        # Server runs in daemon thread, will die with main thread
        pass