package com.example.meloday

import android.content.Context
import android.content.SharedPreferences

/**
 * 桌面组件要显示的播放状态。
 *
 * 状态写在 SharedPreferences 里，这样即使桌面进程随时来要界面，
 * 或者 App 已经被系统回收，组件也还能画出上一次的样子。
 */
object WidgetState {
    private const val PREFS = "melody_widget"
    private const val KEY_TITLE = "title"
    private const val KEY_ARTIST = "artist"
    private const val KEY_PLAYING = "playing"
    private const val KEY_COVER = "cover"
    private const val KEY_HAS_PREV = "hasPrev"
    private const val KEY_HAS_NEXT = "hasNext"

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(
        context: Context,
        title: String,
        artist: String,
        playing: Boolean,
        cover: String?,
        hasPrev: Boolean,
        hasNext: Boolean,
    ) {
        prefs(context).edit()
            .putString(KEY_TITLE, title)
            .putString(KEY_ARTIST, artist)
            .putBoolean(KEY_PLAYING, playing)
            .putString(KEY_COVER, cover)
            .putBoolean(KEY_HAS_PREV, hasPrev)
            .putBoolean(KEY_HAS_NEXT, hasNext)
            .apply()
    }

    fun title(context: Context): String =
        prefs(context).getString(KEY_TITLE, "") ?: ""

    fun artist(context: Context): String =
        prefs(context).getString(KEY_ARTIST, "") ?: ""

    fun playing(context: Context): Boolean = prefs(context).getBoolean(KEY_PLAYING, false)

    fun cover(context: Context): String? = prefs(context).getString(KEY_COVER, null)

    fun hasPrev(context: Context): Boolean = prefs(context).getBoolean(KEY_HAS_PREV, false)

    fun hasNext(context: Context): Boolean = prefs(context).getBoolean(KEY_HAS_NEXT, false)
}
