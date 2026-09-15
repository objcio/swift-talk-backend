#!/usr/bin/env python3
"""Check generated local links, assets, public content counts, and XML without a server."""
import argparse
import json
import re
from collections import defaultdict
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit
import xml.etree.ElementTree as ET


def verify(root):
    errors = defaultdict(set)
    checked = 0
    episodes = json.loads((root / "episodes.json").read_text())
    public_host = urlsplit(episodes[0]["url"]).netloc

    class Links(HTMLParser):
        def __init__(self, path):
            super().__init__()
            self.path = path

        def handle_starttag(self, tag, attrs):
            nonlocal checked
            for key, value in attrs:
                if key not in ("href", "src") or not value:
                    continue
                url = urlsplit(value)
                if (url.scheme and url.scheme not in ("http", "https")) or (url.netloc and url.netloc != public_host):
                    continue
                if not url.path:
                    continue
                resolved = unquote(urlsplit(urljoin("/" + str(self.path), value)).path).lstrip("/")
                target = root / resolved
                checked += 1
                if not target.is_file() and not (target / "index.html").is_file():
                    errors[resolved].add(str(self.path))

    pages = list(root.rglob("*.html"))
    for page in pages:
        Links(page.relative_to(root)).feed(page.read_text())
    for sheet in (root / "assets").rglob("*.css"):
        for path in re.findall(r"url\(['\"]?(/[^)'\"]+)", sheet.read_text()):
            if not (root / unquote(urlsplit(path).path).lstrip("/")).is_file():
                errors[path].add(str(sheet.relative_to(root)))
    ET.parse(root / "episodes.rss")
    ET.parse(root / "sitemap.xml")
    for episode in episodes:
        transcript = root / "transcripts" / f"episode{episode['number']}.md"
        if not transcript.is_file() or not transcript.read_text().strip():
            errors[str(transcript)].add("Missing or empty transcript")
        page = root / unquote(urlsplit(episode["url"]).path).lstrip("/") / "index.html"
        if page.is_file() and 'id="vimeo-player"' not in page.read_text():
            errors[str(page)].add("Missing full Vimeo player")
    if errors:
        for target, sources in sorted(errors.items()):
            print(f"Missing {target} (from {', '.join(sorted(sources)[:3])})")
        raise SystemExit(1)
    print(f"Verified {len(episodes)} episodes and transcripts, {len(pages)} HTML files, {checked} local references, RSS, and sitemap.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site", type=Path, nargs="?", default=Path("_site"))
    verify(parser.parse_args().site)
