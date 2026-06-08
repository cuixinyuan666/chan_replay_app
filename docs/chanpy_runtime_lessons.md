# chan.py runtime lessons

This project uses Vespa/chan.py as the single Chan calculation source. The following notes are project-level lessons learned while wiring chan.py into Android Chaquopy and Windows embedded Python.

## Android Chaquopy: do not depend on chan.py CSV file paths

Commit `83e1dcc` fixed the first major Android runtime issue: the APK could fetch K-line bars and render candlesticks, but no Chan structures were displayed.

The root cause was that chan.py's CSV API expects files in paths derived from the chan.py package layout. On Android, Python source files are packaged inside the APK and those package paths are not a stable writable runtime location. Therefore Android runtime must not rely on writing CSV files into the chan.py package directory and then asking CSV_API to read them.

Required approach:

```text
easy-tdx bars
  -> Android in-memory DataAPI
  -> CChan(data_src="custom:AndroidRuntimeAPI.AndroidRuntimeAPI")
  -> FX / BI / SEG / ZS export
```

This avoids APK filesystem assumptions and keeps Android runtime independent of package-path write permissions.

## Android Chaquopy: CChan running is not enough

Commit `796507f` fixed the second major Android runtime issue: after CChan could run, the app could still show only K-lines if FX / BI / SEG / ZS export logic assumed a single chan.py object shape.

Do not hard-code only one field name, such as:

```text
fx_list
bi_list
seg_list
zs_list
begin_bi
end_bi
high / low / peak_high / peak_low
```

Different chan.py versions and objects may expose lists and values through different attributes, methods, or iterable containers. Export code must use defensive helpers for:

```text
attribute fallback
method fallback
list / tuple / iterable normalization
numeric normalization
FX top/bottom text detection
peak K-line lookup with multiple signatures
```

Concrete rule: when exporting chan.py runtime structures, use compatibility helpers like `_attr`, `_call_any`, `_as_list`, `_to_float`, `_peak_klu`, and support multiple list names such as `fx_list/fx_lst`, `bi_list/bi_list_lst/bi_lst`, `seg_list/seg_lst`, and `zs_list/zs_lst`.

## Regression checklist

When Android shows K-lines but no Chan structures, check in this order:

```text
1. Does meta.warning contain an Android chan.py export exception?
2. Is python/chan.py actually bundled into the APK by Chaquopy sourceSets?
3. Does chanpy_runtime.py use in-memory DataAPI instead of CSV package paths?
4. Does the export layer support the current chan.py object shapes?
5. Are returned fx/bi/seg/zs arrays non-empty before Flutter parsing?
6. Are Flutter parsers preserving raw_index, prices, direction, is_sure, zg/zd/gg/dd?
```

Do not start by changing Flutter drawing code if bars render correctly. First verify the Python returned JSON contains non-empty `fx`, `bi`, `seg`, and `zs` arrays.
