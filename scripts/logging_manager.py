"""
logging_manager.py

Provides enterprise-grade logging for the plugin deployment tool. Recreates the log file on each run, logs all actions with timestamps, and provides user-friendly console output.

Usage:
    from logging_manager import get_logger
    logger = get_logger()
    logger.info('message')
"""
import logging
import os
from datetime import datetime

LOG_FILE = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'deployment.log'))

def get_logger():
    """Get a configured logger that logs to file and console, recreating the log file each run."""
    logger = logging.getLogger('PluginDeploymentLogger')
    if logger.hasHandlers():
        return logger
    logger.setLevel(logging.INFO)
    # File handler (overwrite each run)
    fh = logging.FileHandler(LOG_FILE, mode='w')
    fh.setLevel(logging.INFO)
    # Console handler
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    # Formatter
    formatter = logging.Formatter('[%(asctime)s] %(levelname)s: %(message)s', datefmt='%Y-%m-%d %H:%M:%S')
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    logger.addHandler(fh)
    logger.addHandler(ch)
    return logger
