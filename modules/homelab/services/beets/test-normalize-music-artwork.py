"""Check that recovered embedded covers remain readable by media services."""

import io
import os
import subprocess
import sys
import tempfile
import wave
from pathlib import Path

import mediafile
import yaml
from PIL import Image
from beets.library import Item, Library

with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    music = root / "music"
    music.mkdir()
    track = music / "track.wav"
    with wave.open(str(track), "wb") as audio:
        audio.setparams((1, 2, 44100, 0, "NONE", "not compressed"))
        audio.writeframes(b"\0\0" * 44100)

    image = io.BytesIO()
    Image.new("RGB", (64, 64)).save(image, format="JPEG")
    audio = mediafile.MediaFile(track)
    audio.art = image.getvalue()
    audio.save()

    database = root / "library.db"
    library = Library(str(database), str(music))
    item = Item.from_path(track)
    item.artist = item.albumartist = item.album = "Test"
    library.add_album([item])
    library._close()

    config = root / "config.yaml"
    config.write_text(yaml.safe_dump({
        "directory": str(music),
        "library": str(database),
        "plugins": ["permissions"],
        "permissions": {"file": "664", "dir": "2775"},
    }))
    subprocess.run(
        [sys.executable, sys.argv[1], "--config", str(config)], check=True
    )

    library = Library(str(database), str(music))
    album = next(iter(library.albums()))
    cover = Path(os.fsdecode(album.artpath))
    assert cover.is_file()
    assert cover.stat().st_mode & 0o777 == 0o664
    library._close()
    print("Recovered cover is readable: 0664")
