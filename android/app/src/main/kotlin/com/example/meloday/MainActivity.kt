package com.example.meloday

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    /** 等待权限结果的 Flutter 回调，同一时刻只处理一个请求。 */
    private var pendingPermissionResult: MethodChannel.Result? = null

    /** 组件按钮的动作：Flutter 还没起来时先存着，等它来取。 */
    private var pendingWidgetAction: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 组件把界面拉起来时，动作藏在启动 Intent 里。
        pendingWidgetAction = intent?.getStringExtra(WidgetActionReceiver.EXTRA_ACTION)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        val kind = call.argument<String>("kind") ?: KIND_AUDIO
                        requestMediaPermission(kind, result)
                    }

                    "queryMediaPaths" -> {
                        val kind = call.argument<String>("kind") ?: KIND_AUDIO
                        try {
                            result.success(queryMediaPaths(kind))
                        } catch (error: Exception) {
                            result.error("QUERY_FAILED", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        val widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_CHANNEL,
        )
        widgetChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateMini" -> {
                    WidgetState.save(
                        context = this,
                        title = call.argument<String>("title") ?: "",
                        artist = call.argument<String>("artist") ?: "",
                        playing = call.argument<Boolean>("playing") ?: false,
                        cover = call.argument<String>("cover"),
                        hasPrev = call.argument<Boolean>("hasPrev") ?: false,
                        hasNext = call.argument<Boolean>("hasNext") ?: false,
                    )
                    WidgetRenderer.updateMini(this)
                    result.success(true)
                }

                "takeAction" -> {
                    result.success(pendingWidgetAction)
                    pendingWidgetAction = null
                }

                else -> result.notImplemented()
            }
        }
        WidgetBridge.attach(widgetChannel)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val action = intent.getStringExtra(WidgetActionReceiver.EXTRA_ACTION) ?: return
        if (!WidgetBridge.send(action)) pendingWidgetAction = action
    }

    /** 不同系统版本需要的读取权限。 */
    private fun permissionFor(kind: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return if (kind == KIND_VIDEO) {
                Manifest.permission.READ_MEDIA_VIDEO
            } else {
                Manifest.permission.READ_MEDIA_AUDIO
            }
        }
        return Manifest.permission.READ_EXTERNAL_STORAGE
    }

    private fun requestMediaPermission(
        kind: String,
        result: MethodChannel.Result,
    ) {
        val permission = permissionFor(kind)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            // 上一次请求还没回来，避免回调错位。
            result.success(false)
            return
        }
        pendingPermissionResult = result
        requestPermissions(arrayOf(permission), REQUEST_MEDIA_PERMISSION)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQUEST_MEDIA_PERMISSION) return
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    /** 用 MediaStore 查出手机里全部音频 / 视频的真实路径。 */
    @Suppress("DEPRECATION")
    private fun queryMediaPaths(kind: String): List<String> {
        val isVideo = kind == KIND_VIDEO
        val collection = if (isVideo) {
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }
        val projection = arrayOf(MediaStore.MediaColumns.DATA)
        // 音频只取被系统标记为音乐的条目，排除铃声 / 通知音。
        val selection =
            if (isVideo) null else "${MediaStore.Audio.Media.IS_MUSIC} != 0"

        val paths = mutableListOf<String>()
        contentResolver
            .query(collection, projection, selection, null, null)
            ?.use { cursor ->
                val column = cursor.getColumnIndex(MediaStore.MediaColumns.DATA)
                if (column < 0) return@use
                while (cursor.moveToNext()) {
                    val path = cursor.getString(column)
                    if (!path.isNullOrEmpty()) paths.add(path)
                }
            }
        return paths
    }

    companion object {
        private const val CHANNEL = "meloday/media"
        private const val WIDGET_CHANNEL = "meloday/widget"
        private const val REQUEST_MEDIA_PERMISSION = 4821
        private const val KIND_AUDIO = "audio"
        private const val KIND_VIDEO = "video"
    }
}
