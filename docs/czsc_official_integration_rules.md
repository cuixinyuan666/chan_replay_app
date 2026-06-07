# CZSC 官方调用约束

本项目后续所有 CZSC 缠论元素调用必须遵守以下规则。

## 核心原则

```text
只按 CZSC 官方文档、官方 examples、当前源码暴露接口调用；
不根据旧版字段名或经验猜测对象属性；
不为了显示效果自研替代算法冒充 CZSC 输出。
```

## 当前已确认官方路径

来自 CZSC 官方示例的基础路径：

```python
from czsc import CZSC, ZS, Freq, format_standard_kline

bars = format_standard_kline(df, freq=Freq.F30)
c = CZSC(bars)

fx_list = c.fx_list
bi_list = c.bi_list
zs = ZS(c.bi_list[-7:])
```

## 当前元素策略

```text
FX：使用 c.fx_list
BI：使用 c.bi_list
ZS：使用官方 ZS(bi_list) 构造方式；当前先按示例使用最近 7 笔 ZS(c.bi_list[-7:])
SEG：当前 CZSC 官方核心示例和当前源码未确认直接暴露 c.seg_list；不自研、不假装返回
```

## 禁止事项

```text
禁止假设 c.zs_list 一定存在
禁止假设 c.seg_list 一定存在
禁止根据前端需要自造线段或完整中枢列表并标为 CZSC 结果
禁止将 chan.py、PEL、旧版 CZSC 字段直接套到当前 CZSC 1.x 对象上
```

## 接入新元素前的流程

```text
1. 先查 CZSC 官方 README / docs/examples / crates/czsc-python / crates/czsc-core
2. 找到明确的 Python 调用方式或源码 getter
3. 在 backend/app/czsc_adapter.py 中实现最薄适配层
4. 在 payload.meta 中写明 official_path / policy
5. 前端只显示后端明确返回的数据；没有官方输出就显示为空和 warning
```

## 当前修复状态

```text
backend/app/czsc_adapter.py 已改为：
format_standard_kline(df, freq) -> CZSC(bars) -> fx_list / bi_list -> ZS(c.bi_list[-7:])
```
