"""
config_context.py

Loads config.json once and exposes its values for use across all scripts in the tool.

Usage:
    from config_context import CONFIG
    print(CONFIG['server_ip'])
"""
import json
import os

CONFIG_PATH = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'config.json'))
with open(CONFIG_PATH, 'r') as f:
    CONFIG = json.load(f)
