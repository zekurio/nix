"""Build each Fluxer env file from one SOPS secret without shell expansion."""

import json
import os
from pathlib import Path
import string
import sys


def render(source, templates, destination):
    values = {}
    for line in source.read_text().splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        key, separator, value = line.partition('=')
        if not separator or not key.isidentifier() or key in values:
            raise ValueError('Invalid or duplicate Fluxer env key')
        values[key] = value
    # Validate all files before replacing any of them.
    files = {
        name: "".join(
            f"{key}={string.Template(value).substitute(values)}\n"
            for key, value in variables.items()
        )
        for name, variables in json.loads(templates.read_text()).items()
    }
    os.umask(0o077)
    for name, content in files.items():
        target = destination / name
        temporary = target.with_suffix('.tmp')
        temporary.write_text(content)
        temporary.chmod(0o600)
        temporary.replace(target)


if __name__ == '__main__':
    render(*(Path(arg) for arg in sys.argv[1:]))
