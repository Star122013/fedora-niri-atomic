#!/usr/bin/env python3
"""Expand dnf metalink/mirrorlist URLs into explicit global baseurl lists.

Fedora and RPMFusion serve their repo metadata through MirrorManager, which
picks/orders mirrors from the client's egress IP. From some networks that
lands on a mirror which blocks us (e.g. TUNA), and the `&country=` query
param only helps for countries that actually have their own mirrors --
everywhere else MirrorManager falls back to nearby mirrors (CN again).

This script removes that IP-based decision entirely: for every enabled dnf
repo it expands the metalink into the full global mirror set (minus blocked
hosts) and writes it as a list of `baseurl=` entries. dnf then walks the
list in order and falls back on failure, independent of where we run from.

Subcommands:
  filter                    rewrite /etc/yum.repos.d/*.repo in place
  fetch-rpmfusion <dir>     download the RPMFusion release RPMs into <dir>
"""

from __future__ import annotations

import re
import subprocess
import sys
import urllib.request
from pathlib import Path

REPO_DIR = Path("/etc/yum.repos.d")
BLOCKED = ("mirrors.tuna.tsinghua.edu.cn",)
MIRRORLIST_RE = re.compile(r"^[ \t]*(metalink|mirrorlist)[ \t]*=[ \t]*(\S+)")
URL_RE = re.compile(r"<url\b([^>]*)>([^<]+)</url>")
UA = {"User-Agent": "dnf-mirrors/1 (+bootc-build)"}


def rpm_var(name: str) -> str:
    return subprocess.check_output(["rpm", "-E", name], text=True).strip()


def fetch(url: str) -> str:
    req = urllib.request.Request(url, headers=UA)
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8", "replace")


def expand_vars(url: str) -> str:
    for token in ("releasever", "basearch"):
        value = rpm_var("%fedora") if token == "releasever" else rpm_var("%_arch")
        url = url.replace(f"${{{token}}}", value).replace(f"${token}", value)
    return url


def mirror_bases(url: str) -> list[str]:
    """Return every https mirror base advertised by a metalink, minus blocked."""
    bases: list[str] = []
    for attrs, murl in URL_RE.findall(fetch(expand_vars(url))):
        if 'protocol="https"' not in attrs:
            continue
        base = re.sub(r"/repodata/repomd\.xml$", "", murl.strip())
        if any(blocked in base for blocked in BLOCKED):
            continue
        if base not in bases:
            bases.append(base)
    return bases


def filter_repos() -> int:
    rewritten = 0
    for path in sorted(REPO_DIR.glob("*.repo")):
        lines = path.read_text().splitlines(keepends=True)
        out: list[str] = []
        changed = False
        for line in lines:
            match = MIRRORLIST_RE.match(line)
            if match:
                url = match.group(2)
                if "mirrors.fedoraproject.org" in url or "mirrors.rpmfusion.org" in url:
                    try:
                        bases = mirror_bases(url)
                    except Exception as exc:  # network / parse problems are non-fatal
                        print(f"WARN {path}: {url}: {exc}", file=sys.stderr)
                        bases = []
                    if bases:
                        out.append(f"#{line.rstrip()}\n")
                        out.extend(f"baseurl={base}\n" for base in bases)
                        changed = True
                        continue
            out.append(line)
        if changed:
            path.write_text("".join(out))
            count = sum(1 for line in out if line.startswith("baseurl="))
            print(f"{path}: {count} baseurls")
            rewritten += 1
    return rewritten


def fetch_rpmfusion(dest: str) -> None:
    fedora = rpm_var("%fedora")
    arch = rpm_var("%_arch")
    outdir = Path(dest)
    outdir.mkdir(parents=True, exist_ok=True)
    for kind in ("free", "nonfree"):
        filename = f"rpmfusion-{kind}-release.noarch.rpm"
        target = outdir / filename
        metalink = (
            f"https://mirrors.rpmfusion.org/metalink"
            f"?repo={kind}-fedora-{fedora}&arch={arch}"
        )
        candidates = [
            f"https://download1.rpmfusion.org/{kind}/fedora/"
            f"rpmfusion-{kind}-release-{fedora}.noarch.rpm"
        ]
        try:
            for attrs, murl in URL_RE.findall(fetch(metalink)):
                if 'protocol="https"' not in attrs:
                    continue
                base = re.sub(r"/releases/.*$", "", murl.strip())
                url = f"{base}/rpmfusion-{kind}-release-{fedora}.noarch.rpm"
                if url not in candidates:
                    candidates.append(url)
        except Exception as exc:
            print(f"WARN rpmfusion {kind} metalink: {exc}", file=sys.stderr)

        for url in candidates:
            try:
                req = urllib.request.Request(url, headers=UA)
                with urllib.request.urlopen(req, timeout=60) as resp:
                    target.write_bytes(resp.read())
                print(f"{target} <- {url}")
                break
            except Exception as exc:
                print(f"WARN {url}: {exc}", file=sys.stderr)
        else:
            raise SystemExit(f"no reachable mirror for rpmfusion-{kind}-release")


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[1] == "filter":
        filter_repos()
        return 0
    if len(argv) >= 3 and argv[1] == "fetch-rpmfusion":
        fetch_rpmfusion(argv[2])
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
