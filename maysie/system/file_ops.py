"""
File operations module
Handles file and directory management tasks.
"""

import os
import shutil
import glob
from pathlib import Path
from typing import List, Optional, Tuple

from maysie.utils.logger import get_logger

logger = get_logger(__name__)


class FileOperations:
    """Handles file system operations"""
    
    @staticmethod
    def create_directory(path: str, parents: bool = True) -> Tuple[bool, str]:
        """
        Create directory.
        
        Args:
            path: Directory path
            parents: Create parent directories
            
        Returns:
            Tuple of (success, message)
        """
        try:
            Path(path).mkdir(parents=parents, exist_ok=True)
            return True, f"Directory created: {path}"
        except Exception as e:
            logger.error(f"Failed to create directory {path}: {e}")
            return False, str(e)
    
    @staticmethod
    def delete_file(path: str) -> Tuple[bool, str]:
        """
        Delete file.
        
        Args:
            path: File path
            
        Returns:
            Tuple of (success, message)
        """
        try:
            Path(path).unlink()
            return True, f"File deleted: {path}"
        except Exception as e:
            logger.error(f"Failed to delete file {path}: {e}")
            return False, str(e)
    
    @staticmethod
    def delete_directory(path: str, recursive: bool = False) -> Tuple[bool, str]:
        """
        Delete directory.
        
        Args:
            path: Directory path
            recursive: Delete recursively
            
        Returns:
            Tuple of (success, message)
        """
        try:
            p = Path(path)
            if recursive:
                shutil.rmtree(p)
            else:
                p.rmdir()
            return True, f"Directory deleted: {path}"
        except Exception as e:
            logger.error(f"Failed to delete directory {path}: {e}")
            return False, str(e)
    
    @staticmethod
    def move_file(source: str, destination: str) -> Tuple[bool, str]:
        """
        Move file or directory.
        
        Args:
            source: Source path
            destination: Destination path
            
        Returns:
            Tuple of (success, message)
        """
        try:
            shutil.move(source, destination)
            return True, f"Moved {source} to {destination}"
        except Exception as e:
            logger.error(f"Failed to move {source} to {destination}: {e}")
            return False, str(e)
    
    @staticmethod
    def copy_file(source: str, destination: str) -> Tuple[bool, str]:
        """
        Copy file.
        
        Args:
            source: Source file path
            destination: Destination path
            
        Returns:
            Tuple of (success, message)
        """
        try:
            shutil.copy2(source, destination)
            return True, f"Copied {source} to {destination}"
        except Exception as e:
            logger.error(f"Failed to copy {source} to {destination}: {e}")
            return False, str(e)
    
    @staticmethod
    def copy_directory(source: str, destination: str) -> Tuple[bool, str]:
        """
        Copy directory recursively.
        
        Args:
            source: Source directory path
            destination: Destination directory path
            
        Returns:
            Tuple of (success, message)
        """
        try:
            shutil.copytree(source, destination)
            return True, f"Copied directory {source} to {destination}"
        except Exception as e:
            logger.error(f"Failed to copy directory {source} to {destination}: {e}")
            return False, str(e)
    
    @staticmethod
    def find_files(pattern: str, path: str = ".", recursive: bool = True) -> Tuple[bool, List[str]]:
        """
        Find files matching pattern.
        
        Args:
            pattern: Glob pattern (e.g., "*.py")
            path: Search path
            recursive: Search recursively
            
        Returns:
            Tuple of (success, list of matching files)
        """
        try:
            if recursive:
                pattern_path = f"{path}/**/{pattern}"
                matches = glob.glob(pattern_path, recursive=True)
            else:
                pattern_path = f"{path}/{pattern}"
                matches = glob.glob(pattern_path)
            
            return True, matches
        except Exception as e:
            logger.error(f"Failed to find files with pattern {pattern}: {e}")
            return False, []
    
    @staticmethod
    def get_file_info(path: str) -> Tuple[bool, dict]:
        """
        Get file information.
        
        Args:
            path: File path
            
        Returns:
            Tuple of (success, info dict)
        """
        try:
            p = Path(path)
            stat = p.stat()
            
            info = {
                'path': str(p.absolute()),
                'name': p.name,
                'size': stat.st_size,
                'size_human': FileOperations._human_readable_size(stat.st_size),
                'is_file': p.is_file(),
                'is_dir': p.is_dir(),
                'created': stat.st_ctime,
                'modified': stat.st_mtime,
                'permissions': oct(stat.st_mode)[-3:],
            }
            
            return True, info
        except Exception as e:
            logger.error(f"Failed to get file info for {path}: {e}")
            return False, {}
    
    @staticmethod
    def list_directory(path: str, show_hidden: bool = False) -> Tuple[bool, List[str]]:
        """
        List directory contents.
        
        Args:
            path: Directory path
            show_hidden: Include hidden files
            
        Returns:
            Tuple of (success, list of entries)
        """
        try:
            p = Path(path)
            entries = []
            
            for item in p.iterdir():
                if not show_hidden and item.name.startswith('.'):
                    continue
                entries.append(str(item))
            
            return True, sorted(entries)
        except Exception as e:
            logger.error(f"Failed to list directory {path}: {e}")
            return False, []
    
    @staticmethod
    def find_large_files(path: str, min_size_mb: int = 100, limit: int = 20) -> Tuple[bool, List[dict]]:
        """
        Find large files.
        
        Args:
            path: Search path
            min_size_mb: Minimum size in MB
            limit: Maximum number of results
            
        Returns:
            Tuple of (success, list of file info dicts)
        """
        try:
            min_size_bytes = min_size_mb * 1024 * 1024
            large_files = []
            
            for root, dirs, files in os.walk(path):
                # Skip system directories
                dirs[:] = [d for d in dirs if not d.startswith('.') and d not in ['proc', 'sys', 'dev']]
                
                for file in files:
                    try:
                        file_path = os.path.join(root, file)
                        size = os.path.getsize(file_path)
                        
                        if size >= min_size_bytes:
                            large_files.append({
                                'path': file_path,
                                'size': size,
                                'size_human': FileOperations._human_readable_size(size)
                            })
                    except (OSError, PermissionError):
                        continue
            
            # Sort by size descending
            large_files.sort(key=lambda x: x['size'], reverse=True)
            return True, large_files[:limit]
            
        except Exception as e:
            logger.error(f"Failed to find large files in {path}: {e}")
            return False, []
    
    @staticmethod
    def _human_readable_size(size_bytes: int) -> str:
        """Convert bytes to human-readable format"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if size_bytes < 1024.0:
                return f"{size_bytes:.1f} {unit}"
            size_bytes /= 1024.0
        return f"{size_bytes:.1f} PB"


# Global instance
_global_file_ops: Optional[FileOperations] = None


def get_file_operations() -> FileOperations:
    """Get global file operations instance"""
    global _global_file_ops
    if _global_file_ops is None:
        _global_file_ops = FileOperations()
    return _global_file_ops