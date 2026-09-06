"""Run with Python, the Copyparty executable, and an evaluated config template.

Uses temporary volumes and dummy credentials; never reads production passwords.
"""

import base64
import os
from pathlib import Path
import re
import socket
import subprocess
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


with tempfile.TemporaryDirectory(prefix="copyparty-check-") as temp:
    root = Path(temp)
    config = Path(sys.argv[2]).read_text()
    accounts = re.search(r"\[accounts\]\n(.*?)(?=\n\[)", config, re.S)
    owner = accounts.group(1).strip().split(":", 1)[0]
    config = config[: accounts.start(1)] + f"  {owner}: test-password\n  outsider: other-password\n" + config[accounts.end(1) :]
    volumes = re.findall(r"\[(/[^\]]+)\]\n  (/[^\n]+)", config)
    for index, (virtual, physical) in enumerate(volumes):
        directory = root / str(index)
        directory.mkdir()
        (directory / "probe.txt").write_text("private contents")
        (directory / "escape").symlink_to(root / "outside.txt")
        config = config.replace(f"\n  {physical}\n", f"\n  {directory}\n")
    (root / "outside.txt").write_text("outside the volume")
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        port = listener.getsockname()[1]
    config = re.sub(r"  p: \d+", f"  p: {port}", config)
    config = config.replace("/var/cache/copyparty", str(root / "cache"))
    config = re.sub(r"  site: .*", f"  site: http://127.0.0.1:{port}/", config)
    config_path = root / "config.conf"
    config_path.write_text(config)

    def request(path, credentials=None, data=None):
        headers = {}
        if credentials:
            headers["Authorization"] = "Basic " + base64.b64encode(credentials.encode()).decode()
        req = Request(f"http://127.0.0.1:{port}{path}", data=data, headers=headers, method="PUT" if data is not None else "GET")
        try:
            with urlopen(req, timeout=5) as response:
                return response.status, response.read()
        except HTTPError as error:
            return error.code, error.read()

    with (root / "server.log").open("w+") as log:
        server = subprocess.Popen([sys.argv[1], "-c", str(config_path)], cwd=root, env={**os.environ, "HOME": temp, "XDG_CONFIG_HOME": temp}, stdout=log, stderr=log)
        try:
            for attempt in range(100):
                if server.poll() is not None:
                    log.seek(0)
                    raise AssertionError(log.read())
                try:
                    request("/")
                    break
                except URLError:
                    time.sleep(0.1)
            for virtual, _ in volumes:
                for credentials in [None, "outsider:other-password"]:
                    status, _ = request(virtual + "/probe.txt", credentials)
                    assert status in (401, 403, 404), (virtual, status)
                    status, _ = request(virtual + "/blocked.txt", credentials, b"blocked")
                    assert status in (401, 403, 404), (virtual, status)
                credentials = owner + ":test-password"
                assert request(virtual + "/probe.txt", credentials) == (200, b"private contents")
                status, _ = request(virtual + "/uploaded.txt", credentials, b"upload works")
                assert 200 <= status < 300, status
                assert request(virtual + "/uploaded.txt", credentials) == (200, b"upload works")
                status, _ = request(virtual + "/escape", credentials)
                assert status in (403, 404), status
            print("Copyparty access checks passed: owner read/write, anonymous and outsider denied, symlink escape denied.")
        finally:
            server.terminate()
            try:
                server.wait(timeout=10)
            except subprocess.TimeoutExpired:
                server.kill()
                server.wait()
