package com.example.chan_replay_app

import com.chaquo.python.Python
import com.chaquo.python.android.AndroidPlatform
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "chan_replay_app/python_easy_tdx"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "loadKline" -> {
                    val payload = call.argument<String>("payload") ?: "{}"
                    try {
                        if (!Python.isStarted()) {
                            Python.start(AndroidPlatform(this))
                        }
                        val py = Python.getInstance()
                        val module = py.getModule("easy_tdx_runtime")
                        val response = module.callAttr("load_kline_json", payload).toString()
                        result.success(response)
                    } catch (e: Exception) {
                        result.error("PYTHON_EASY_TDX_ERROR", e.message, e.stackTraceToString())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
