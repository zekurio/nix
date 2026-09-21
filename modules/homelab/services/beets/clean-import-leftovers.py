#!/usr/bin/env python3
"""Remove unchanged sidecars only after Beets moves every audio file in a folder."""

import argparse
import json
import os
from pathlib import Path

AUDIO = {'.aac', '.aif', '.aiff', '.ape', '.asf', '.dff', '.dsf', '.flac',
         '.m4a', '.m4b', '.mp3', '.mp4', '.mpc', '.oga', '.ogg', '.opus',
         '.spx', '.tta', '.wav', '.wma', '.wv'}
SIDECARS = {'.jpg', '.jpeg', '.png', '.webp', '.gif', '.nfo', '.txt', '.log',
            '.cue', '.m3u', '.m3u8', '.pls', '.sfv', '.md5', '.lrc'}


def signature(path):
    stat = path.lstat()
    return [stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns]


def entries(root):
    for directory, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = [name for name in dirs if name != '.hist'
                   and not (Path(directory) / name).is_symlink()]
        yield Path(directory), files


def record(roots):
    result = []
    for root in roots:
        root = Path(root)
        if root.is_symlink():
            continue
        folders = dict(entries(root))
        imported = set()
        for directory, files in folders.items():
            if any(Path(name).suffix.lower() in AUDIO for name in files):
                while directory != root:
                    imported.add(directory)
                    directory = directory.parent
        for directory in sorted(imported, key=lambda p: len(p.parts), reverse=True):
            sidecars = {}
            for name in folders[directory]:
                path = directory / name
                if path.suffix.lower() in SIDECARS and not path.is_symlink():
                    sidecars[name] = signature(path)
            result.append({'directory': str(directory),
                           'identity': signature(directory)[:2], 'sidecars': sidecars})
    return result


def clean(records):
    for record in records:
        directory = Path(record['directory'])
        if (not directory.is_dir() or directory.is_symlink()
                or signature(directory)[:2] != record['identity']):
            continue
        remaining = list(directory.iterdir())
        # Unknown files, partial uploads, subfolders, and symlinks block cleanup.
        if any(path.is_symlink() or not path.is_file()
               or path.name not in record['sidecars']
               or signature(path) != record['sidecars'][path.name]
               for path in remaining):
            continue
        for path in remaining:
            path.unlink()
            print(f'Removed imported album sidecar: {path}', flush=True)
        directory.rmdir()


def prune(roots):
    for root in roots:
        if Path(root).is_symlink():
            continue
        directories = [directory for directory, _ in entries(root)]
        for directory in reversed(directories):
            if directory == Path(root):
                continue
            try:
                directory.rmdir()
            except OSError:
                pass


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['record', 'clean', 'prune'])
    parser.add_argument('paths', nargs='+')
    args = parser.parse_args()
    if args.action == 'record':
        print(json.dumps(record(args.paths)))
    elif args.action == 'clean':
        clean(json.loads(Path(args.paths[0]).read_text()))
    else:
        prune(args.paths)


if __name__ == '__main__':
    main()
