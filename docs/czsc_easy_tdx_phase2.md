# CZSC + easy-tdx 第二阶段

分支：`czsc_easy_tdx`

## 第二阶段目标

在第一阶段“后端返回 CZSC 元素，Flutter 负责显示”的基础上，补齐复盘工具所需的交互能力：

```text
多级别接口
多级别结果切换
信号面板
后端结果逐K回放
最近/自选参数入口
```

## 后端新增

新增接口：

```text
GET /api/czsc/multi
```

示例：

```text
/api/czsc/multi?symbol=000001&market=SZ&freqs=MIN5,MIN30,DAILY&adjust=QFQ&count=800
```

返回结构：

```json
{
  "symbol": "000001.SZ",
  "freqs": ["MIN5", "MIN30", "DAILY"],
  "results": {
    "MIN5": {
      "bars": [],
      "fx": [],
      "bi": [],
      "seg": [],
      "zs": [],
      "signals": {}
    },
    "MIN30": {},
    "DAILY": {}
  }
}
```

## Flutter 新增

文件：

```text
lib/data/czsc_easy_tdx_source.dart
lib/ui/pages/czsc_easy_tdx_page.dart
```

新增能力：

```text
1. 单级别加载：/api/czsc/analyze
2. 多级别加载：/api/czsc/multi
3. 多级别周期选择：MIN1 / MIN5 / MIN15 / MIN30 / MIN60 / DAILY / WEEKLY / MONTHLY
4. 已加载级别切换：在同一 KlineChart 中切换不同周期结果
5. 信号面板：显示当前级别 signals，并展示各级别 K/BI/ZS/SIG 统计
6. 后端结果逐K：不重新请求后端，按 cursor 截断 bars/fx/bi/seg/zs 后显示
7. 最近参数：记录最近加载或手动保存的请求参数，便于重复加载
```

## 当前边界

```text
1. 后端逐K仍是“前端截断已返回结果”，不是后端逐K增量计算。
2. 最近参数当前为内存态，App 重启后不保留。
3. 多级别联立目前先做结果并列展示，尚未做跨级别买卖点聚合。
4. WebSocket 实时推送未接入，留到第三阶段。
```

## 建议本地验证

后端：

```bash
cd backend
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Flutter：

```bash
flutter pub get
flutter run
```

在 `CZSC后端` 页中：

```text
1. 后端地址保持 http://10.0.2.2:8000，真机改为电脑局域网 IP
2. 输入 000001 / SZ / DAILY
3. 点“单级别”验证单周期显示
4. 勾选 MIN5、MIN30、DAILY 后点“多级别”
5. 用周期 Chip 切换显示级别
6. 点“信号面板”检查 signals 与各级别统计
7. 切换“逐K”，使用底部 Bar Replay 控制回放
```
