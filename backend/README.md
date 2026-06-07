# CZSC + easy-tdx 后端

后端职责：

```text
easy-tdx 获取 K线 -> 按 CZSC 官方路径计算分型/笔/中枢 -> FastAPI 输出统一 JSON
```

## CZSC 调用原则

本项目后续所有缠论元素调用必须严格按 CZSC 官方文档、示例和源码暴露接口执行，不按字段名想当然猜测。

当前官方对齐路径：

```python
from czsc import CZSC, ZS, Freq, format_standard_kline

bars = format_standard_kline(df, freq=Freq.F30)
c = CZSC(bars)
fx_list = c.fx_list
bi_list = c.bi_list
zs = ZS(c.bi_list[-7:])
```

当前边界：

```text
1. FX 使用 c.fx_list
2. BI 使用 c.bi_list
3. ZS 按官方示例使用 ZS(c.bi_list[-7:]) 尝试构造最近中枢
4. SEG 当前未在 CZSC 官方核心示例中作为 c.seg_list 暴露，不自研线段，seg 返回空数组
5. 不再使用 c.zs_list / c.seg_list 的想当然读取方式
```

## 安装

```bash
cd backend
python -m venv .venv
. .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

## 启动

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Android 模拟器访问电脑本机后端时，Flutter 默认可以使用：

```text
http://10.0.2.2:8000
```

真机访问时，把 Flutter 页面里的后端地址改成电脑的局域网地址，例如：

```text
http://192.168.1.8:8000
```

## 接口

```text
GET /health
GET /api/czsc/analyze?symbol=000001&market=SZ&freq=DAILY&adjust=QFQ&count=800
GET /api/czsc/multi?symbol=000001&market=SZ&freqs=MIN5,MIN30,DAILY&adjust=QFQ&count=800
```

支持参数：

```text
symbol  股票代码，例如 000001 或 600000
market  SZ / SH，可留空自动推断
freq    单级别周期：MIN1 / MIN5 / MIN15 / MIN30 / MIN60 / DAILY / WEEKLY / MONTHLY
freqs   多级别周期列表，逗号分隔，例如 MIN5,MIN30,DAILY
adjust  QFQ / HFQ / NONE
count   10~5000
start   yyyy-MM-dd，可选
end     yyyy-MM-dd，可选
```

## 单级别返回结构

```json
{
  "symbol": "000001.SZ",
  "freq": "DAILY",
  "bars": [],
  "new_bars": [],
  "fx": [],
  "bi": [],
  "seg": [],
  "zs": [],
  "signals": {},
  "engine_warning": "线段 SEG 未按自研逻辑生成...",
  "meta": {
    "official_path": "format_standard_kline(df, freq) -> CZSC(bars) -> fx_list/bi_list -> ZS(c.bi_list[-7:])",
    "counts": {}
  },
  "source": {
    "name": "easy-tdx"
  }
}
```

## 多级别返回结构

```json
{
  "symbol": "000001.SZ",
  "freqs": ["MIN5", "MIN30", "DAILY"],
  "results": {
    "MIN5": {},
    "MIN30": {},
    "DAILY": {}
  }
}
```

Flutter 第二阶段读取 `results[freq].bars / fx / bi / seg / zs / signals`，在页面内切换级别、查看信号，并支持后端结果的逐 K 回放显示。
