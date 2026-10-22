package com.example.meloday

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/** 把当前播放状态画成桌面组件的界面（单行：光盘 + 歌名作者 + 三按钮）。 */
object WidgetRenderer {

    /** 刷新「正在播放」组件。 */
    fun updateMini(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, MelodyMiniWidgetProvider::class.java),
        )
        if (ids.isEmpty()) return
        val views = mini(context)
        for (id in ids) manager.updateAppWidget(id, views)
    }

    fun mini(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_mini)
        val title = WidgetState.title(context)
        val artist = WidgetState.artist(context)
        val playing = WidgetState.playing(context)

        views.setTextViewText(
            R.id.widget_title,
            title.ifEmpty { "Melody" },
        )
        views.setTextViewText(
            R.id.widget_artist,
            if (title.isEmpty()) {
                "点一下打开 Melody"
            } else {
                artist.ifEmpty { "未知作者" }
            },
        )
        views.setImageViewResource(
            R.id.widget_toggle,
            if (playing) R.drawable.ic_widget_pause else R.drawable.ic_widget_play,
        )

        // 播放时旋转整张光盘；暂停 / 未播放时显示静态光盘。
        views.setViewVisibility(
            R.id.widget_disc_static,
            if (playing) View.GONE else View.VISIBLE,
        )
        views.setViewVisibility(
            R.id.widget_disc_spin,
            if (playing) View.VISIBLE else View.GONE,
        )

        views.setViewVisibility(
            R.id.widget_prev,
            if (WidgetState.hasPrev(context)) View.VISIBLE else View.INVISIBLE,
        )
        views.setViewVisibility(
            R.id.widget_next,
            if (WidgetState.hasNext(context)) View.VISIBLE else View.INVISIBLE,
        )

        views.setOnClickPendingIntent(
            R.id.widget_prev,
            action(context, WidgetActionReceiver.ACTION_PREV, 101),
        )
        views.setOnClickPendingIntent(
            R.id.widget_toggle,
            action(context, WidgetActionReceiver.ACTION_TOGGLE, 102),
        )
        views.setOnClickPendingIntent(
            R.id.widget_next,
            action(context, WidgetActionReceiver.ACTION_NEXT, 103),
        )
        views.setOnClickPendingIntent(R.id.widget_mini_root, open(context, 100))
        return views
    }

    private fun action(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, WidgetActionReceiver::class.java).apply {
            this.action = WidgetActionReceiver.ACTION_WIDGET_CLICK
            putExtra(WidgetActionReceiver.EXTRA_ACTION, action)
        }
        return PendingIntent.getBroadcast(context, requestCode, intent, pendingFlags())
    }

    private fun open(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(context, requestCode, intent, pendingFlags())
    }

    private fun pendingFlags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
}
