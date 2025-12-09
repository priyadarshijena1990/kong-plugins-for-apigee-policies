"""
plugin_discovery.py

Discovers available plugin directories in the specified local path.

Functions:
    get_plugin_dirs(plugin_path): Returns a list of plugin directory names.

Usage:
    from plugin_discovery import get_plugin_dirs
    plugins = get_plugin_dirs('apigee-policies-based-plugins')
"""
import os

def get_plugin_dirs(plugin_path):
    """Return a list of plugin directory names in the given path that contain a handler.lua or schema.lua."""
    plugin_dirs = []
    for name in os.listdir(plugin_path):
        path = os.path.join(plugin_path, name)
        if os.path.isdir(path):
            if any(f in os.listdir(path) for f in ["handler.lua", "schema.lua"]):
                plugin_dirs.append(name)
    return plugin_dirs
