#!/usr/bin/env python3
"""Run the complete chan.py vs Dart alignment benchmark."""

from __future__ import annotations

import argparse
import csv
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


def normalize_csv_for_compare(csv_path: str, out_dir: Path) -> str:
    """Create one sanitized CSV used by both chan.py and Dart exports.

    Vespa rejects invalid OHLC rows, for example close < low. For comparison,
    both engines must receive the exact same cleaned input. This function keeps
    open/close unchanged and expands high/low to contain open/high/low/close.
    """
    source = (ROOT / csv_path).resolve() if not Path(csv_path).is_absolute() else Path(csv_path)
    if not source.exists():
        raise FileNotFoundError(f"CSV not found: {source}")
    target = out_dir / "input_normalized.csv"
    corrections = 0
    rows = 0

    with source.open("r", encoding="utf-8-sig", newline="") as fin, target.open("w", encoding="utf-8", newline="") as fout:
        reader = csv.DictReader(fin)
        if reader.fieldnames is None:
            raise ValueError(f"CSV has no header: {source}")
        field_map = {name.strip().lower(): name for name in reader.fieldnames}
        time_col = field_map.get("time") or field_map.get("time_key") or field_map.get("dt") or field_map.get("date")
        open_col = field_map.get("open")
        high_col = field_map.get("high")
        low_col = field_map.get("low")
        close_col = field_map.get("close")
        volume_col = field_map.get("volume") or field_map.get("vol")
        missing = [
            name
            for name, col in {
                "time/time_key/dt/date": time_col,
                "open": open_col,
                "high": high_col,
                "low": low_col,
                "close": close_col,
            }.items()
            if col is None
        ]
        if missing:
            raise ValueError(f"CSV missing required columns: {', '.join(missing)}")

        writer = csv.writer(fout)
        writer.writerow(["time", "open", "high", "low", "close", "volume"])
        for row in reader:
            if not row:
                continue
            time_val = str(row[time_col]).strip()
            open_val = float(str(row[open_col]).strip())
            high_val = float(str(row[high_col]).strip())
            low_val = float(str(row[low_col]).strip())
            close_val = float(str(row[close_col]).strip())
            fixed_high = max(open_val, high_val, low_val, close_val)
            fixed_low = min(open_val, high_val, low_val, close_val)
            if fixed_high != high_val or fixed_low != low_val:
                corrections += 1
            volume_val = str(row[volume_col]).strip() if volume_col is not None else "0"
            writer.writerow([
                time_val,
                f"{open_val:.6f}".rstrip("0").rstrip("."),
                f"{fixed_high:.6f}".rstrip("0").rstrip("."),
                f"{fixed_low:.6f}".rstrip("0").rstrip("."),
                f"{close_val:.6f}".rstrip("0").rstrip("."),
                volume_val,
            ])
            rows += 1

    print(f"Normalized CSV written: {target} rows={rows} ohlc_corrections={corrections}")
    return str(target)


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
    normalized_csv = normalize_csv_for_compare(args.csv, out_dir)

    chanpy_json = out_dir / "chanpy.json"
    dart_json = out_dir / "dart.json"
    report_json = out_dir / "diff_report.json"
    report_md = out_dir / "diff_report.md"

    if not args.skip_chanpy:
        cmd = [
            sys.executable,
            str(TOOL_DIR / "chanpy_export.py"),
            "--csv",
            normalized_csv,
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

    run(dart_export_command(normalized_csv, dart_json))

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
