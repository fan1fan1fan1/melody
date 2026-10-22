package com.example.meloday

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 桌面组件上的按钮点击都发到这里。
 *
 * App 还在运行：直接把动作交给 Flutter，界面不用弹出来。
 * App 已经被回收：带着动作把界面拉起来，Flutter 启动后自己取走处理。
 */
class WidgetActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_WIDGET_CLICK) return
        val action = intent.getStringExtra(EXTRA_ACTION) ?: return
        if (WidgetBridge.send(action)) return

        val launch = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_ACTION, action)
        }
        context.startActivity(launch)
    }

    companion object {
        const val ACTION_WIDGET_CLICK = "com.example.meloday.WIDGET_CLICK"
        const val EXTRA_ACTION = "melody_widget_action"

        const val ACTION_TOGGLE = "toggle"
        const val ACTION_NEXT = "next"
        const val ACTION_PREV = "prev"
    }
}
