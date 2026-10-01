import json
import os
from pathlib import Path
import sys
import tempfile


config_file = Path(sys.argv[1])
pin_directory = sys.argv[2]
if config_file.exists():
    config = json.loads(config_file.read_text())
    if config.get("jellyfin", {}).get("configPath") != pin_directory:
        config.setdefault("jellyfin", {})["configPath"] = pin_directory
        # Keep credentials and all other settings. Replace the file atomically.
        descriptor, temporary = tempfile.mkstemp(dir=config_file.parent)
        try:
            with os.fdopen(descriptor, "w") as output:
                json.dump(config, output, indent=2)
                output.write("\n")
            os.chmod(temporary, config_file.stat().st_mode & 0o777)
            os.replace(temporary, config_file)
        finally:
            Path(temporary).unlink(missing_ok=True)
