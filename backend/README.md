# vespa_tdx easy-tdx 后端

本分支后端只负责获取 K 线数据，不再计算 CZSC 缠论结构。

```text
easy-tdx 获取 K线 -> FastAPI 返回 bars JSON -> Flutter 本地 Vespa/Dart 缠论引擎计算 FX/BI/SEG/ZS
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

真机访问时，把 Flutter 本地复盘页里的后端地址改成电脑局域网 IP，例如：

```text
http://192.168.1.8:8000
```

## 接口

```text
GET /health
GET /api/tdx/kline?symbol=000001&market=SZ&freq=DAILY&adjust=QFQ&count=800&start=2020-01-01&end=2024-12-31
```

支持参数：

```text
symbol  股票代码，例如 000001 或 600000
market  SZ / SH，可留空自动推断
freq    MIN1 / MIN5 / MIN15 / MIN30 / MIN60 / DAILY / WEEKLY / MONTHLY
adjust  QFQ / HFQ / NONE
count   10~5000
start   yyyy-MM-dd，可选
end     yyyy-MM-dd，可选
```

返回结构：

```json
{
  "ok": true,
  "engine": "flutter-vespa-dart",
  "source": {"name": "easy-tdx", "symbol": "000001.SZ", "freq": "DAILY"},
  "bars": [
    {"id": 0, "dt": "2024-01-02 00:00:00", "open": 1.0, "high": 1.1, "low": 0.9, "close": 1.0, "vol": 1000}
  ]
}
```
