package com.example.meloday

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

/** 组件一：竖条迷你播放器。 */
class MelodyMiniWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val views = WidgetRenderer.mini(context)
        for (id in appWidgetIds) appWidgetManager.updateAppWidget(id, views)
    }
}
