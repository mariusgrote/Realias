"""User settings for Realias, stored as JSON next to the app's data.

The file is created with the defaults on first use, so it is always there to
edit.
"""

import json
import os

CONFIG_DIR = os.path.expanduser("~/Library/Application Support/Realias")
CONFIG_PATH = os.path.join(CONFIG_DIR, "config.json")

# name_source picks which name the new alias is built from:
#   "alias"  - the name of the original alias file
#   "target" - the name of the item the alias points at
DEFAULTS = {
    "suffix": " (this Mac)",
    "name_source": "alias",
}

NAME_SOURCES = ("alias", "target")


class ConfigError(Exception):
    pass


def _write_defaults():
    os.makedirs(CONFIG_DIR, exist_ok=True)
    with open(CONFIG_PATH, "w") as f:
        json.dump(DEFAULTS, f, indent=2)
        f.write("\n")


def load():
    if not os.path.exists(CONFIG_PATH):
        _write_defaults()
        return dict(DEFAULTS)

    try:
        with open(CONFIG_PATH) as f:
            stored = json.load(f)
    except ValueError as e:
        raise ConfigError("%s is not valid JSON:\n%s" % (CONFIG_PATH, e))
    if not isinstance(stored, dict):
        raise ConfigError("%s must contain a JSON object" % CONFIG_PATH)

    settings = dict(DEFAULTS)
    settings.update({k: v for k, v in stored.items() if k in DEFAULTS})

    if not isinstance(settings["suffix"], str):
        raise ConfigError('"suffix" must be text')
    if settings["name_source"] not in NAME_SOURCES:
        raise ConfigError('"name_source" must be one of: %s'
                          % ", ".join(NAME_SOURCES))
    return settings
