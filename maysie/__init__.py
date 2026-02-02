

import sys
import os

if sys.version_info < (3, 9):
    raise RuntimeError("Maysie requires Python 3.9 or higher")

PACKAGE_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR = os.path.dirname(PACKAGE_DIR)

CONFIG_DIR = os.environ.get('MAYSIE_CONFIG_DIR', '/etc/maysie')
LOG_DIR = os.environ.get('MAYSIE_LOG_DIR', '/var/log/maysie')
DATA_DIR = os.environ.get('MAYSIE_DATA_DIR', '/opt/maysie')

__version__ = "1.0.0"
__author__ = "Manjil Timalsina"
__license__ = "MIT"