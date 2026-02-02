"""
Process management module
Handles process listing, control, and application launching.
"""

import os
import signal
import subprocess
import psutil
from typing import List, Optional, Tuple, Dict

from maysie.utils.logger import get_logger
from maysie.system.sudo_handler import get_sudo_handler

logger = get_logger(__name__)


class ProcessManager:
    """Manages system processes"""
    
    def __init__(self):
        """Initialize process manager"""
        self.sudo_handler = get_sudo_handler()
    
    def list_processes(self, filter_name: Optional[str] = None) -> List[Dict]:
        """
        List running processes.
        
        Args:
            filter_name: Optional process name filter
            
        Returns:
            List of process info dicts
        """
        try:
            processes = []
            
            for proc in psutil.process_iter(['pid', 'name', 'username', 'cpu_percent', 'memory_percent']):
                try:
                    info = proc.info
                    
                    if filter_name and filter_name.lower() not in info['name'].lower():
                        continue
                    
                    processes.append({
                        'pid': info['pid'],
                        'name': info['name'],
                        'user': info['username'],
                        'cpu': f"{info['cpu_percent']:.1f}%",
                        'memory': f"{info['memory_percent']:.1f}%"
                    })
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
            return processes
            
        except Exception as e:
            logger.error(f"Failed to list processes: {e}")
            return []
    
    def kill_process(self, pid: int, force: bool = False) -> Tuple[bool, str]:
        """
        Kill process by PID.
        
        Args:
            pid: Process ID
            force: Use SIGKILL instead of SIGTERM
            
        Returns:
            Tuple of (success, message)
        """
        try:
            proc = psutil.Process(pid)
            sig = signal.SIGKILL if force else signal.SIGTERM
            
            proc.send_signal(sig)
            proc.wait(timeout=5)
            
            return True, f"Process {pid} terminated"
            
        except psutil.NoSuchProcess:
            return False, f"Process {pid} not found"
        except psutil.AccessDenied:
            # Try with sudo
            try:
                signal_name = "KILL" if force else "TERM"
                rc, _, stderr = self.sudo_handler.run_command(f"kill -{signal_name} {pid}")
                if rc == 0:
                    return True, f"Process {pid} terminated (with sudo)"
                else:
                    return False, f"Failed to kill process: {stderr}"
            except Exception as e:
                return False, f"Access denied: {e}"
        except Exception as e:
            logger.error(f"Failed to kill process {pid}: {e}")
            return False, str(e)
    
    def kill_by_name(self, name: str, force: bool = False) -> Tuple[bool, str]:
        """
        Kill all processes matching name.
        
        Args:
            name: Process name
            force: Use SIGKILL
            
        Returns:
            Tuple of (success, message)
        """
        try:
            killed = []
            
            for proc in psutil.process_iter(['pid', 'name']):
                try:
                    if name.lower() in proc.info['name'].lower():
                        success, msg = self.kill_process(proc.info['pid'], force)
                        if success:
                            killed.append(proc.info['pid'])
                except (psutil.NoSuchProcess, psutil.AccessDenied):
                    continue
            
            if killed:
                return True, f"Killed {len(killed)} process(es): {', '.join(map(str, killed))}"
            else:
                return False, f"No processes found matching '{name}'"
                
        except Exception as e:
            logger.error(f"Failed to kill processes by name {name}: {e}")
            return False, str(e)
    
    def launch_application(self, app_name: str, args: Optional[List[str]] = None) -> Tuple[bool, str]:
        """
        Launch application.
        
        Args:
            app_name: Application name or command
            args: Optional command arguments
            
        Returns:
            Tuple of (success, message)
        """
        try:
            command = [app_name]
            if args:
                command.extend(args)
            
            # Launch detached
            process = subprocess.Popen(
                command,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                start_new_session=True
            )
            
            return True, f"Launched {app_name} (PID: {process.pid})"
            
        except FileNotFoundError:
            return False, f"Application not found: {app_name}"
        except Exception as e:
            logger.error(f"Failed to launch {app_name}: {e}")
            return False, str(e)
    
    def get_process_info(self, pid: int) -> Tuple[bool, Dict]:
        """
        Get detailed process information.
        
        Args:
            pid: Process ID
            
        Returns:
            Tuple of (success, info dict)
        """
        try:
            proc = psutil.Process(pid)
            
            info = {
                'pid': proc.pid,
                'name': proc.name(),
                'status': proc.status(),
                'username': proc.username(),
                'cpu_percent': f"{proc.cpu_percent(interval=0.1):.1f}%",
                'memory_percent': f"{proc.memory_percent():.1f}%",
                'memory_mb': f"{proc.memory_info().rss / 1024 / 1024:.1f} MB",
                'num_threads': proc.num_threads(),
                'create_time': proc.create_time(),
                'cmdline': ' '.join(proc.cmdline()),
            }
            
            return True, info
            
        except psutil.NoSuchProcess:
            return False, {}
        except Exception as e:
            logger.error(f"Failed to get process info for {pid}: {e}")
            return False, {}
    
    def get_system_stats(self) -> Dict:
        """
        Get system resource statistics.
        
        Returns:
            System stats dict
        """
        try:
            cpu_percent = psutil.cpu_percent(interval=1)
            memory = psutil.virtual_memory()
            disk = psutil.disk_usage('/')
            
            return {
                'cpu_percent': f"{cpu_percent:.1f}%",
                'cpu_count': psutil.cpu_count(),
                'memory_percent': f"{memory.percent:.1f}%",
                'memory_used': f"{memory.used / 1024 / 1024 / 1024:.1f} GB",
                'memory_total': f"{memory.total / 1024 / 1024 / 1024:.1f} GB",
                'disk_percent': f"{disk.percent:.1f}%",
                'disk_used': f"{disk.used / 1024 / 1024 / 1024:.1f} GB",
                'disk_total': f"{disk.total / 1024 / 1024 / 1024:.1f} GB",
            }
            
        except Exception as e:
            logger.error(f"Failed to get system stats: {e}")
            return {}


# Global instance
_global_process_manager: Optional[ProcessManager] = None


def get_process_manager() -> ProcessManager:
    """Get global process manager instance"""
    global _global_process_manager
    if _global_process_manager is None:
        _global_process_manager = ProcessManager()
    return _global_process_manager