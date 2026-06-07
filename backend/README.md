# CZSC + easy-tdx 后端

第一阶段后端只做三件事：

```text
easy-tdx 获取 K线 -> CZSC 计算分型/笔/线段/中枢 -> FastAPI 输出统一 JSON
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

## 返回结构

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
  "source": {
    "name": "easy-tdx"
  }
}
```

Flutter 端第一阶段读取 `bars / fx / bi / seg / zs` 并转换为现有 `ChanSnapshot`，然后复用当前 `KlineChart` 绘制。
