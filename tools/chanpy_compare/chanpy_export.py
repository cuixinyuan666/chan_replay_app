#!/usr/bin/env python3
"""Export Vespa314/chan.py structures to a normalized JSON file.

This tool intentionally stays outside app runtime. It is a benchmark harness:
- Same CSV input as Dart export.
- Python side uses a local clone of Vespa314/chan.py.
- Output schema matches dart_export.dart as closely as possible.

Because chan.py versions may expose slightly different attributes, the script
uses multiple fallbacks and also writes raw JSON when CChan.toJson() is present.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any, Iterable


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", default="assets/sample_data/000001_daily.csv")
    parser.add_argument("--out", default="build/chanpy_compare/chanpy.json")
    parser.add_argument("--chanpy-path", default=os.environ.get("CHANPY_PATH", "../chan.py"))
    parser.add_argument("--code", default=None, help="chan.py code argument. Defaults to CSV path for DATA_SRC.CSV.")
    parser.add_argument("--begin", default=None)
    parser.add_argument("--end", default=None)
    parser.add_argument("--freq", default="DAY")
    parser.add_argument("--adjust", default="QFQ")
    return parser.parse_args()


def add_chanpy_path(path: str) -> None:
    root = Path(path).resolve()
    if not root.exists():
        raise FileNotFoundError(f"chan.py path not found: {root}")
    sys.path.insert(0, str(root))


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
    attr = mapping.get(key, "K_DAY")
    return getattr(KL_TYPE, attr)


def pick_autype(AUTYPE: Any, adjust: str) -> Any:
    key = adjust.strip().upper()
    if key == "HFQ":
        return getattr(AUTYPE, "HFQ")
    if key == "NONE":
        return getattr(AUTYPE, "NONE")
    return getattr(AUTYPE, "QFQ")


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


def obj_index(obj: Any) -> Any:
    return getattr_any(obj, ["idx", "index", "klu_idx", "id"], None)


def obj_time(obj: Any) -> Any:
    value = getattr_any(obj, ["time", "date", "dt"], None)
    return str(value) if value is not None else None


def obj_price(obj: Any, names: Iterable[str]) -> Any:
    value = getattr_any(obj, names, None)
    try:
        return float(value)
    except (TypeError, ValueError):
        return value


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
        fx_text = str(fx).lower()
        if "unknown" in fx_text or "none" in fx_text:
            continue
        rows.append(normalize_fx(len(rows), item))
    return rows


def normalize_fx(i: int, item: Any) -> dict[str, Any]:
    fx = getattr_any(item, ["fx", "fx_type", "type"], None)
    text = str(fx).lower()
    is_top = "top" in text or "ding" in text or "peak" in text
    return {
        "index": obj_index(item) if obj_index(item) is not None else i,
        "raw_index": getattr_any(item, ["raw_index", "klu_idx", "idx"], None),
        "time": obj_time(item),
        "type": "top" if is_top else "bottom",
        "price": obj_price(item, ["high", "low", "fx", "price"]),
        "repr": repr(item),
    }


def export_bi(level: Any) -> list[dict[str, Any]]:
    bi_list = getattr_any(level, ["bi_list", "bi_lst"], None)
    rows = []
    for i, bi in enumerate(as_list(bi_list)):
        begin = getattr_any(bi, ["begin_klc", "start_klc", "begin", "start"], None)
        end = getattr_any(bi, ["end_klc", "end"], None)
        direction = str(getattr_any(bi, ["dir", "direction", "bi_dir"], "")).lower()
        rows.append({
            "index": getattr_any(bi, ["idx", "index"], i),
            "start_raw_index": obj_index(begin),
            "end_raw_index": obj_index(end),
            "start_time": obj_time(begin),
            "end_time": obj_time(end),
            "start_price": obj_price(bi, ["begin_val", "start_price", "low", "high"]),
            "end_price": obj_price(bi, ["end_val", "end_price", "high", "low"]),
            "direction": "up" if "up" in direction else "down" if "down" in direction else direction,
            "is_sure": bool(getattr_any(bi, ["is_sure"], True)),
            "repr": repr(bi),
        })
    return rows


def export_seg(level: Any) -> list[dict[str, Any]]:
    seg_list = getattr_any(level, ["seg_list", "seg_lst"], None)
    rows = []
    for i, seg in enumerate(as_list(seg_list)):
        begin_bi = getattr_any(seg, ["start_bi", "begin_bi", "begin"], None)
        end_bi = getattr_any(seg, ["end_bi", "end"], None)
        direction = str(getattr_any(seg, ["dir", "direction"], "")).lower()
        rows.append({
            "index": getattr_any(seg, ["idx", "index"], i),
            "start_bi_index": obj_index(begin_bi),
            "end_bi_index": obj_index(end_bi),
            "direction": "up" if "up" in direction else "down" if "down" in direction else direction,
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
            "zg": obj_price(zs, ["high", "zg"]),
            "zd": obj_price(zs, ["low", "zd"]),
            "gg": obj_price(zs, ["peak_high", "gg"]),
            "dd": obj_price(zs, ["peak_low", "dd"]),
            "repr": repr(zs),
        })
    return rows


def main() -> None:
    args = parse_args()
    add_chanpy_path(args.chanpy_path)
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

    code = args.code or str(Path(args.csv).resolve())
    chan = CChan(
        code=code,
        begin_time=args.begin,
        end_time=args.end,
        data_src=DATA_SRC.CSV,
        lv_list=[kl_type],
        config=config,
        autype=autype,
        extra_kl=None,
    )

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
