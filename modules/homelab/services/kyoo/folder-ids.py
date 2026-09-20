"""Use explicit Arr folder IDs before title-based anime identification."""

from pathlib import PurePosixPath
import re


def folder_guess(path):
    parts = PurePosixPath(path)
    for parent in parts.parents:
        match = re.fullmatch(r"(.+) \((\d{4})\) \[(tmdbid|tvdbid)-(\d+)\]", parent.name)
        if not match:
            continue
        title, year, provider, identifier = match.groups()
        if provider == "tmdbid":
            # A movie folder can also contain extras; do not identify those as films.
            if parent != parts.parent:
                return None
            kind, episodes, key = "movie", [], "themoviedatabase"
        else:
            numbering = re.search(r"\bS(\d+)E(\d+(?:E\d+)*)\b", parts.name, re.I)
            if not numbering:
                return None
            season, numbers = numbering.groups()
            episodes = [
                {"season": int(season), "episode": int(number)}
                for number in re.split("[Ee]", numbers)
            ]
            kind, key = "episode", "tvdb"
        return {
            "title": title,
            "years": [int(year)],
            "kind": kind,
            "extra_kind": None,
            "episodes": episodes,
            "external_id": {key: identifier},
            "from_": "arr-folder-id",
        }
    return None
