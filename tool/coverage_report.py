#!/usr/bin/env python3
"""Compute FireRacoon coverage buckets from LCOV and optionally enforce mins."""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass


@dataclass
class FileCov:
    path: str
    hit: int
    found: int


def parse_lcov(path: str) -> list[FileCov]:
    files: list[FileCov] = []
    cur: str | None = None
    hit = found = 0
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if line.startswith("SF:"):
                cur = line[3:]
                hit = found = 0
            elif line.startswith("LH:"):
                hit = int(line[3:])
            elif line.startswith("LF:"):
                found = int(line[3:])
            elif line == "end_of_record" and cur is not None:
                files.append(FileCov(cur, hit, found))
                cur = None
    return files


def norm(path: str) -> str:
    if path.startswith("lib/"):
        return path[4:]
    marker = "/lib/"
    if marker in path:
        return path.split(marker, 1)[1]
    return path


ALWAYS_EXCLUDE_PREFIXES = (
    "l10n/app_localizations",
    "main.dart",
    "fun_modes/painters/",
)

PLATFORM_EXCLUDE = {
    "services/biometric_auth_facade_io.dart",
    "services/biometric_auth_facade_stub.dart",
    "utils/web_backend_proxy.dart",
    "utils/json_file_store.dart",
    "utils/json_file_store_io.dart",
    "utils/json_file_store_stub.dart",
    "utils/avatar_file_store.dart",
    "utils/avatar_file_store_io.dart",
    "utils/avatar_file_store_stub.dart",
}

APP_LOGIC_TOPS = {
    "providers",
    "services",
    "utils",
    "models",
    "router",
    "theme",
    "fun_modes",
}


def excluded_app(rel: str) -> bool:
    if rel in PLATFORM_EXCLUDE:
        return True
    if rel == "main.dart":
        return True
    return any(rel.startswith(p) for p in ALWAYS_EXCLUDE_PREFIXES)


def rate(hit: int, found: int) -> float:
    return 100.0 if found == 0 else 100.0 * hit / found


def summarize(files: list[FileCov], predicate) -> tuple[float, int, int]:
    hit = found = 0
    for f in files:
        rel = norm(f.path)
        if predicate(rel):
            hit += f.hit
            found += f.found
    return rate(hit, found), hit, found


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--app", default="coverage/lcov.info")
    p.add_argument("--engine", default="packages/engine/coverage/lcov.info")
    p.add_argument("--mcp", default="packages/mcp/coverage/lcov.info")
    p.add_argument("--check", action="store_true")
    p.add_argument(
        "--engine-min",
        type=float,
        default=float(os.environ.get("ENGINE_MIN", "99")),
    )
    p.add_argument(
        "--mcp-min",
        type=float,
        default=float(os.environ.get("MCP_MIN", "99")),
    )
    p.add_argument(
        "--app-logic-min",
        type=float,
        default=float(os.environ.get("APP_LOGIC_MIN", "99")),
    )
    p.add_argument(
        "--ui-min",
        type=float,
        default=float(os.environ.get("UI_MIN", "60")),
    )
    args = p.parse_args()

    app = parse_lcov(args.app)
    engine = parse_lcov(args.engine)
    mcp = parse_lcov(args.mcp)

    engine_r, _, _ = summarize(engine, lambda _rel: True)
    mcp_r, _, _ = summarize(mcp, lambda _rel: True)

    def app_logic(rel: str) -> bool:
        if excluded_app(rel):
            return False
        top = rel.split("/", 1)[0]
        return top in APP_LOGIC_TOPS

    def ui(rel: str) -> bool:
        return rel.split("/", 1)[0] in {"screens", "widgets"}

    logic_r, _, _ = summarize(app, app_logic)
    ui_r, _, _ = summarize(app, ui)

    print(f"Engine:    {engine_r:.1f}%  (min {args.engine_min})")
    print(f"MCP:       {mcp_r:.1f}%  (min {args.mcp_min})")
    print(f"App logic: {logic_r:.1f}%  (min {args.app_logic_min})")
    print(f"UI:        {ui_r:.1f}%  (min {args.ui_min})")

    if not args.check:
        return 0

    fail = False
    for label, value, minimum in (
        ("Engine", engine_r, args.engine_min),
        ("MCP", mcp_r, args.mcp_min),
        ("App logic", logic_r, args.app_logic_min),
        ("UI", ui_r, args.ui_min),
    ):
        if value + 1e-9 < minimum:
            print(f"FAIL: {label} {value:.1f}% < {minimum}%", file=sys.stderr)
            fail = True
        else:
            print(f"OK: {label} {value:.1f}% >= {minimum}%")
    return 1 if fail else 0


if __name__ == "__main__":
    sys.exit(main())
