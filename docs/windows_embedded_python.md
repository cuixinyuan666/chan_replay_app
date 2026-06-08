# Windows embedded Python runtime

`origin_vespa_tdx` 的 Windows 目标是随 App 携带便携 Python，而不是依赖 Anaconda、系统 Python 或手工设置 `CHANPY_PATH`。

最终目录：

```text
chan_replay_app/
  python/
    python.exe
    python311.dll
    python311.zip
    Lib/
    site-packages/
    app_engine.py
    requirements-windows.txt
    chan.py/
      Chan.py
      ChanConfig.py
      Common/
      KLine/
      Bi/
      Seg/
      ZS/
      DataAPI/
```

Flutter 当前 Windows 自动启动顺序：

```text
1. python/python.exe
2. backend/.venv/Scripts/python.exe
3. python
4. py -3
```

因此只要 `python/python.exe` 存在，App 会优先使用项目内便携 Python。

## 准备文件

手工下载：

```text
1. Windows embeddable package，例如 python-3.11.9-embed-amd64.zip
2. get-pip.py
```

脚本不会主动联网下载这些文件；这样可以避免构建脚本隐藏网络行为。

## 一键准备便携目录

在项目根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File scripts/setup_windows_embedded_python.ps1 `
  -EmbeddedZip C:\path\to\python-3.11.9-embed-amd64.zip `
  -GetPipPy C:\path\to\get-pip.py `
  -ChanPySource ..\chan.py
```

脚本会：

```text
1. 解压 embeddable Python 到 python/
2. 修改 python*._pth，启用 import site，并加入 Lib/site-packages
3. 安装 pip
4. 安装 python/requirements-windows.txt
5. 可选复制 chan.py 到 python/chan.py
6. 检查 python/app_engine.py
7. 执行 app_engine.py --help 作为 smoke test
```

## 验证

```powershell
.\python\python.exe .\python\app_engine.py --help
.\python\python.exe -m pip list
```

启动本地服务：

```powershell
.\python\python.exe .\python\app_engine.py --host 127.0.0.1 --port 8000
```

Flutter 运行时会自动优先使用 `python/python.exe`。

## 注意

- `python/app_engine.py` 不是多余文件；它是 Windows 本地 Python 服务入口。
- `python/chan.py` 是 Vespa/chan.py 源码目录；它应与 `app_engine.py` 同级。
- 不要把 `app_engine.py` 放进 `python/chan.py/`。
- 不要把 embeddable Python 二进制提交到 Git；发布包阶段再放入。