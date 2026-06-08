#!/usr/bin/env python3
"""Run the complete chan.py vs Dart alignment benchmark."""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOL_DIR = Path(__file__).resolve().parent


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", default="assets/sample_data/000001_daily.csv")
    parser.add_argument("--chanpy-path", default="../chan.py")
    parser.add_argument("--out", default="build/chanpy_compare")
    parser.add_argument("--freq", default="DAY")
    parser.add_argument("--adjust", default="QFQ")
    parser.add_argument("--begin", default=None)
    parser.add_argument("--end", default=None)
    parser.add_argument("--skip-chanpy", action="store_true", help="Only run Dart export and diff existing chanpy.json.")
    return parser.parse_args()


def resolve_command(candidates: list[str]) -> str | None:
    for candidate in candidates:
        found = shutil.which(candidate)
        if found:
            return found
    return None


def dart_export_command(csv_path: str, out_path: Path) -> list[str]:
    # Windows subprocess with shell=False may not resolve bare `dart` to dart.bat
    # in some Conda/PowerShell environments. Resolve the real executable/batch
    # path explicitly, then fall back to Flutter.
    if os.name == "nt":
        dart = resolve_command(["dart.exe", "dart.bat", "dart.cmd", "dart"])
        flutter = resolve_command(["flutter.bat", "flutter.cmd", "flutter.exe", "flutter"])
    else:
        dart = resolve_command(["dart"])
        flutter = resolve_command(["flutter"])

    if dart:
        return [
            dart,
            "run",
            "tools/chanpy_compare/dart_export.dart",
            "--csv",
            csv_path,
            "--out",
            str(out_path),
        ]

    if flutter:
        return [
            flutter,
            "pub",
            "run",
            "tools/chanpy_compare/dart_export.dart",
            "--csv",
            csv_path,
            "--out",
            str(out_path),
        ]

    raise SystemExit(
        "ERROR: Cannot find Dart or Flutter executable in PATH.\n"
        "Fix one of these:\n"
        "  1. Add Flutter SDK bin directory to PATH, for example C:\\src\\flutter\\bin\n"
        "  2. Run Dart export manually in a shell where `dart --version` works:\n"
        "     dart run tools/chanpy_compare/dart_export.dart --csv assets/sample_data/000001_daily.csv --out build/chanpy_compare/dart.json\n"
        "  3. Then run diff_chan_outputs.py manually."
    )


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd))
    subprocess.run(cmd, cwd=ROOT, check=True)


def main() -> None:
    args = parse_args()
    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    chanpy_json = out_dir / "chanpy.json"
    dart_json = out_dir / "dart.json"
    report_json = out_dir / "diff_report.json"
    report_md = out_dir / "diff_report.md"

    if not args.skip_chanpy:
        cmd = [
            sys.executable,
            str(TOOL_DIR / "chanpy_export.py"),
            "--csv",
            args.csv,
            "--chanpy-path",
            args.chanpy_path,
            "--freq",
            args.freq,
            "--adjust",
            args.adjust,
            "--out",
            str(chanpy_json),
        ]
        if args.begin:
            cmd += ["--begin", args.begin]
        if args.end:
            cmd += ["--end", args.end]
        run(cmd)

    run(dart_export_command(args.csv, dart_json))

    run([
        sys.executable,
        str(TOOL_DIR / "diff_chan_outputs.py"),
        "--chanpy",
        str(chanpy_json),
        "--dart",
        str(dart_json),
        "--out-json",
        str(report_json),
        "--out-md",
        str(report_md),
    ])

    print(f"\nDone. Open {report_md}")


if __name__ == "__main__":
    main()
