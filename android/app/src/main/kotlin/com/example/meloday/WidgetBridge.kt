package com.example.meloday

import io.flutter.plugin.common.MethodChannel

/**
 * 桌面组件按钮与正在运行的 Flutter 之间的桥。
 *
 * 组件按钮点击后会走 [WidgetActionReceiver]，如果 App 还活着就把动作直接
 * 交给 Flutter 处理（不用把界面弹出来）；App 已经被回收时返回 false，
 * 由接收者带着动作启动界面，等 Flutter 起来后再处理。
 */
object WidgetBridge {
    private var channel: MethodChannel? = null

    fun attach(value: MethodChannel?) {
        channel = value
    }

    fun send(action: String): Boolean {
        val current = channel ?: return false
        return try {
            current.invokeMethod("action", action)
            true
        } catch (_: Throwable) {
            false
        }
    }
}
