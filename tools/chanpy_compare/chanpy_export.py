#!/usr/bin/env python3
"""Export Vespa314/chan.py structures to a normalized JSON file.

This is a benchmark harness, not app runtime code. It prepares a CSV file in the
format expected by Vespa's DATA_SRC.CSV, runs CChan, and exports FX/BI/SEG/ZS in
roughly the same schema as tools/chanpy_compare/dart_export.dart.
"""

from __future__ import annotations

import argparse
import csv
import inspect
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Iterable


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", default="assets/sample_data/000001_daily.csv")
    parser.add_argument("--out", default="build/chanpy_compare/chanpy.json")
    parser.add_argument("--chanpy-path", default=os.environ.get("CHANPY_PATH", "../chan.py"))
    parser.add_argument("--code", default=None, help="Temporary chan.py CSV code. Defaults to a safe name from CSV stem.")
    parser.add_argument("--begin", default=None)
    parser.add_argument("--end", default=None)
    parser.add_argument("--freq", default="DAY")
    parser.add_argument("--adjust", default="QFQ")
    return parser.parse_args()


def add_chanpy_path(path: str) -> Path:
    root = Path(path).resolve()
    if not root.exists():
        raise FileNotFoundError(f"chan.py path not found: {root}")
    sys.path.insert(0, str(root))
    return root


def import_chanpy():
    from Chan import CChan  # type: ignore
    from ChanConfig import CChanConfig  # type: ignore
    from Common.CEnum import AUTYPE, DATA_SRC, KL_TYPE  # type: ignore

    return CChan, CChanConfig, AUTYPE, DATA_SRC, KL_TYPE


def pick_kl_type(KL_TYPE: Any, freq: str) -> Any:
    key = freq.strip().upper()
    mapping = {
        "DAY": "K_DAY",
        "DAILY": "K_DAY",
        "WEEK": "K_WEEK",
        "WEEKLY": "K_WEEK",
        "MON": "K_MON",
        "MONTH": "K_MON",
        "MONTHLY": "K_MON",
        "MIN1": "K_1M",
        "1M": "K_1M",
        "MIN5": "K_5M",
        "5M": "K_5M",
        "MIN15": "K_15M",
        "15M": "K_15M",
        "MIN30": "K_30M",
        "30M": "K_30M",
        "MIN60": "K_60M",
        "60M": "K_60M",
    }
    return getattr(KL_TYPE, mapping.get(key, "K_DAY"))


def pick_autype(AUTYPE: Any, adjust: str) -> Any:
    key = adjust.strip().upper()
    if key == "HFQ":
        return getattr(AUTYPE, "HFQ")
    if key == "NONE":
        return getattr(AUTYPE, "NONE")
    return getattr(AUTYPE, "QFQ")


def kl_suffix(kl_type: Any) -> str:
    name = getattr(kl_type, "name", str(kl_type))
    if name.startswith("K_"):
        return name[2:].lower()
    return str(name).lower().replace("kl_type.", "").replace("k_", "")


def safe_code_from_csv(csv_path: Path) -> str:
    stem = re.sub(r"[^0-9A-Za-z_]+", "_", csv_path.stem).strip("_") or "sample"
    return f"chanpy_compare_{stem}"


def normalize_time_for_chanpy(value: str) -> str:
    text = value.strip().strip('"').replace("T", " ")
    if len(text) >= 19 and re.match(r"^\d{4}-\d{2}-\d{2} ", text):
        return text[:19]
    if len(text) >= 10 and re.match(r"^\d{4}-\d{2}-\d{2}", text):
        return text[:10]
    if len(text) >= 8 and re.match(r"^\d{8}", text):
        raw = text[:8]
        return f"{raw[:4]}-{raw[4:6]}-{raw[6:8]}"
    return text


def prepare_chanpy_csv(csv_path: str, chanpy_root: Path, kl_type: Any, code: str | None) -> str:
    source = Path(csv_path).resolve()
    if not source.exists():
        raise FileNotFoundError(f"CSV not found: {source}")
    tmp_code = code or safe_code_from_csv(source)
    target = chanpy_root / f"{tmp_code}_{kl_suffix(kl_type)}.csv"

    with source.open("r", encoding="utf-8-sig", newline="") as fin:
        reader = csv.DictReader(fin)
        if reader.fieldnames is None:
            raise ValueError(f"CSV has no header: {source}")
        field_map = {name.strip().lower(): name for name in reader.fieldnames}
        time_col = field_map.get("time") or field_map.get("time_key") or field_map.get("dt") or field_map.get("date")
        open_col = field_map.get("open")
        high_col = field_map.get("high")
        low_col = field_map.get("low")
        close_col = field_map.get("close")
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
        rows = [
            [
                normalize_time_for_chanpy(row[time_col] or ""),
                str(row[open_col]).strip(),
                str(row[high_col]).strip(),
                str(row[low_col]).strip(),
                str(row[close_col]).strip(),
            ]
            for row in reader
            if row
        ]

    with target.open("w", encoding="utf-8", newline="") as fout:
        writer = csv.writer(fout)
        writer.writerow(["time_key", "open", "high", "low", "close"])
        writer.writerows(rows)

    print(f"Prepared chan.py CSV: {target}")
    return tmp_code


def safe_json(value: Any) -> Any:
    if value is None or isinstance(value, (str, int, float, bool)):
        return value
    if isinstance(value, dict):
        return {str(k): safe_json(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [safe_json(v) for v in value]
    return str(value)


def getattr_any(obj: Any, names: Iterable[str], default: Any = None) -> Any:
    for name in names:
        if hasattr(obj, name):
            value = getattr(obj, name)
            return value() if callable(value) and name.startswith("get_") else value
    return default


def call_any(obj: Any, names: Iterable[str], default: Any = None) -> Any:
    for name in names:
        if hasattr(obj, name):
            value = getattr(obj, name)
            if callable(value):
                try:
                    return value()
                except TypeError:
                    continue
            return value
    return default


def as_list(obj: Any) -> list[Any]:
    if obj is None:
        return []
    if isinstance(obj, list):
        return obj
    if isinstance(obj, tuple):
        return list(obj)
    try:
        return list(obj)
    except TypeError:
        return []


def to_float(value: Any) -> Any:
    try:
        return float(value)
    except (TypeError, ValueError):
        return value


def obj_index(obj: Any) -> Any:
    return getattr_any(obj, ["idx", "index", "klu_idx", "id"], None)


def obj_time(obj: Any) -> Any:
    value = getattr_any(obj, ["time", "time_begin", "date", "dt"], None)
    return str(value) if value is not None else None


def get_peak_klu(klc: Any, is_high: bool) -> Any:
    if klc is None:
        return None
    if hasattr(klc, "get_peak_klu"):
        try:
            return klc.get_peak_klu(is_high=is_high)
        except TypeError:
            pass
    if is_high and hasattr(klc, "get_high_peak_klu"):
        return klc.get_high_peak_klu()
    if (not is_high) and hasattr(klc, "get_low_peak_klu"):
        return klc.get_low_peak_klu()
    return None


def get_level(chan: Any, kl_type: Any) -> Any:
    try:
        return chan[kl_type]
    except Exception:
        pass
    try:
        return chan[0]
    except Exception:
        pass
    return chan


def make_cchan(CChan: Any, kwargs: dict[str, Any]) -> Any:
    try:
        signature = inspect.signature(CChan)
        params = signature.parameters
        accepts_kwargs = any(param.kind == inspect.Parameter.VAR_KEYWORD for param in params.values())
        filtered = dict(kwargs) if accepts_kwargs else {k: v for k, v in kwargs.items() if k in params}
        return CChan(**filtered)
    except (TypeError, ValueError) as first_error:
        working = dict(kwargs)
        for _ in range(len(working) + 1):
            try:
                return CChan(**working)
            except TypeError as exc:
                text = str(exc)
                if "unexpected keyword argument" in text and "'" in text:
                    unsupported = text.split("'")[1]
                    if unsupported in working:
                        working.pop(unsupported)
                        continue
                raise
        raise first_error


def is_top_fx_text(text: str) -> bool:
    lower = text.lower()
    return "top" in lower or "ding" in lower or "peak" in lower or "fx_type.top" in lower


def is_bottom_fx_text(text: str) -> bool:
    lower = text.lower()
    return "bottom" in lower or "di" in lower or "fx_type.bottom" in lower


def export_fx(level: Any) -> list[dict[str, Any]]:
    direct = getattr_any(level, ["fx_list", "fx_lst"], None)
    if direct is not None:
        return [normalize_fx(i, x) for i, x in enumerate(as_list(direct))]

    candidates = getattr_any(level, ["lst", "kl_list", "klc_list", "klc_lst"], None)
    rows = []
    for item in as_list(candidates):
        fx = getattr_any(item, ["fx", "fx_type"], None)
        if fx is None:
            continue
        fx_text = str(fx)
        low = fx_text.lower()
        if "unknown" in low or "none" in low:
            continue
        rows.append(normalize_fx(len(rows), item))
    return rows


def normalize_fx(i: int, item: Any) -> dict[str, Any]:
    fx = getattr_any(item, ["fx", "fx_type", "type"], None)
    fx_text = str(fx)
    is_top = is_top_fx_text(fx_text)
    peak_klu = get_peak_klu(item, is_high=is_top)
    return {
        "index": obj_index(item) if obj_index(item) is not None else i,
        "raw_index": obj_index(peak_klu) if peak_klu is not None else obj_index(item),
        "time": obj_time(peak_klu) if peak_klu is not None else obj_time(item),
        "type": "top" if is_top else "bottom",
        "price": to_float(getattr_any(item, ["high"], None) if is_top else getattr_any(item, ["low"], None)),
        "repr": repr(item),
    }


def bi_begin_klu(bi: Any) -> Any:
    return call_any(bi, ["get_begin_klu"], None) or get_peak_klu(getattr_any(bi, ["begin_klc", "start_klc", "begin", "start"], None), is_high=False)


def bi_end_klu(bi: Any) -> Any:
    return call_any(bi, ["get_end_klu"], None) or get_peak_klu(getattr_any(bi, ["end_klc", "end"], None), is_high=True)


def bi_direction(bi: Any) -> str:
    direction = str(getattr_any(bi, ["dir", "direction", "bi_dir"], "")).lower()
    return "up" if "up" in direction else "down" if "down" in direction else direction


def export_bi(level: Any) -> list[dict[str, Any]]:
    bi_list = getattr_any(level, ["bi_list", "bi_lst"], None)
    rows = []
    for i, bi in enumerate(as_list(bi_list)):
        begin_klu = bi_begin_klu(bi)
        end_klu = bi_end_klu(bi)
        rows.append({
            "index": getattr_any(bi, ["idx", "index"], i),
            "start_raw_index": obj_index(begin_klu),
            "end_raw_index": obj_index(end_klu),
            "start_time": obj_time(begin_klu),
            "end_time": obj_time(end_klu),
            "start_price": to_float(call_any(bi, ["get_begin_val"], None)),
            "end_price": to_float(call_any(bi, ["get_end_val"], None)),
            "direction": bi_direction(bi),
            "is_sure": bool(getattr_any(bi, ["is_sure"], True)),
            "repr": repr(bi),
        })
    return rows


def export_seg(level: Any) -> list[dict[str, Any]]:
    seg_list = getattr_any(level, ["seg_list", "seg_lst"], None)
    rows = []
    for i, seg in enumerate(as_list(seg_list)):
        start_bi = getattr_any(seg, ["start_bi", "begin_bi", "begin"], None)
        end_bi = getattr_any(seg, ["end_bi", "end"], None)
        begin_klu = call_any(seg, ["get_begin_klu"], None)
        end_klu = call_any(seg, ["get_end_klu"], None)
        rows.append({
            "index": getattr_any(seg, ["idx", "index"], i),
            "start_bi_index": obj_index(start_bi),
            "end_bi_index": obj_index(end_bi),
            "start_raw_index": obj_index(begin_klu),
            "end_raw_index": obj_index(end_klu),
            "start_price": to_float(call_any(seg, ["get_begin_val"], None)),
            "end_price": to_float(call_any(seg, ["get_end_val"], None)),
            "direction": bi_direction(seg),
            "is_sure": bool(getattr_any(seg, ["is_sure"], True)),
            "repr": repr(seg),
        })
    return rows


def export_zs(level: Any) -> list[dict[str, Any]]:
    zs_list = getattr_any(level, ["zs_list", "zs_lst"], None)
    rows = []
    for i, zs in enumerate(as_list(zs_list)):
        begin_bi = getattr_any(zs, ["begin_bi", "start_bi", "bi_in"], None)
        end_bi = getattr_any(zs, ["end_bi", "bi_out"], None)
        rows.append({
            "index": getattr_any(zs, ["idx", "index"], i),
            "start_bi_index": obj_index(begin_bi),
            "end_bi_index": obj_index(end_bi),
            "start_raw_index": obj_index(getattr_any(zs, ["begin"], None)),
            "end_raw_index": obj_index(getattr_any(zs, ["end"], None)),
            "zg": to_float(getattr_any(zs, ["high", "zg"], None)),
            "zd": to_float(getattr_any(zs, ["low", "zd"], None)),
            "gg": to_float(getattr_any(zs, ["peak_high", "gg"], None)),
            "dd": to_float(getattr_any(zs, ["peak_low", "dd"], None)),
            "repr": repr(zs),
        })
    return rows


def main() -> None:
    args = parse_args()
    chanpy_root = add_chanpy_path(args.chanpy_path)
    CChan, CChanConfig, AUTYPE, DATA_SRC, KL_TYPE = import_chanpy()
    kl_type = pick_kl_type(KL_TYPE, args.freq)
    autype = pick_autype(AUTYPE, args.adjust)

    config = CChanConfig({
        "trigger_step": False,
        "skip_step": 0,
        "seg_algo": "chan",
        "bi_algo": "normal",
        "bi_strict": True,
        "zs_algo": "normal",
        "zs_combine": True,
        "zs_combine_mode": "zs",
        "one_bi_zs": False,
    })

    code = prepare_chanpy_csv(args.csv, chanpy_root, kl_type, args.code)
    chan = make_cchan(CChan, {
        "code": code,
        "begin_time": args.begin,
        "end_time": args.end,
        "data_src": DATA_SRC.CSV,
        "lv_list": [kl_type],
        "config": config,
        "autype": autype,
        "extra_kl": None,
    })

    level = get_level(chan, kl_type)
    raw_json = None
    if hasattr(chan, "toJson"):
        try:
            raw_json = safe_json(chan.toJson())
        except Exception as exc:  # noqa: BLE001
            raw_json = {"toJson_error": str(exc)}

    output = {
        "engine": "vespa_chanpy",
        "csv": args.csv,
        "chanpy_path": str(Path(args.chanpy_path).resolve()),
        "prepared_code": code,
        "prepared_csv": str(chanpy_root / f"{code}_{kl_suffix(kl_type)}.csv"),
        "fx": export_fx(level),
        "bi": export_bi(level),
        "seg": export_seg(level),
        "zs": export_zs(level),
        "raw_json": raw_json,
    }

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    raw_path = out.with_name("chanpy_raw.json")
    raw_path.write_text(json.dumps(raw_json, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"chan.py export written: {out}")


if __name__ == "__main__":
    main()
