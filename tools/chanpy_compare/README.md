# chanpy_compare

`chanpy_compare` 用于把当前 Dart 缠论引擎和 `Vespa314/chan.py` 输出放在同一份 CSV K线数据上做结构化对齐。

目标输出：

```text
FX 列表
BI 起止点
SEG 起止点、方向、is_sure
ZS 起止笔、ZG/ZD/GG/DD
```

## 使用顺序

### 1. 准备 Vespa/chan.py

建议把 Vespa 仓库 clone 到项目外部，例如：

```bash
git clone https://github.com/Vespa314/chan.py.git ../chan.py
```

`chan.py` README 说明核心类是 `CChan`，并且数据源支持 `DATA_SRC.CSV`、配置使用 `CChanConfig`，运行后可通过 `CChan[0].bi_list`、`seg_list` 等对象读取缠论结构。

### 2. 准备 CSV

默认使用项目已有 CSV：

```text
assets/sample_data/000001_daily.csv
```

CSV 字段要求：

```text
time,open,high,low,close,volume
```

### 3. 一键运行

```bash
python tools/chanpy_compare/run_compare.py \
  --csv assets/sample_data/000001_daily.csv \
  --chanpy-path ../chan.py \
  --out build/chanpy_compare
```

该脚本会依次执行：

```text
1. Python 侧调用 Vespa/chan.py 输出 chanpy.json
2. Dart 侧调用当前 ChanReplayEngine 输出 dart.json
3. diff_chan_outputs.py 生成 diff_report.json 和 diff_report.md
```

### 4. 单独运行 Dart 侧

```bash
dart run tools/chanpy_compare/dart_export.dart \
  --csv assets/sample_data/000001_daily.csv \
  --out build/chanpy_compare/dart.json
```

### 5. 单独运行 Vespa/chan.py 侧

```bash
python tools/chanpy_compare/chanpy_export.py \
  --csv assets/sample_data/000001_daily.csv \
  --chanpy-path ../chan.py \
  --out build/chanpy_compare/chanpy.json
```

## 输出说明

`diff_report.md` 会按模块统计数量和首个差异：

```text
FX
BI
SEG
ZS
```

后续修复顺序固定为：

```text
BI -> SEG -> ZS
```

禁止绕过该基准直接按肉眼改算法。

## 注意

`chanpy_export.py` 对 Vespa/chan.py 的公开 API 做了多层兼容：优先读取 `toJson()`，其次读取 `bi_list / seg_list / zs_list` 等对象。不同版本的 Vespa 仓库对象字段可能略有差异，因此首次运行后需要用 `chanpy_raw.json` 检查真实字段，再收紧字段映射。
