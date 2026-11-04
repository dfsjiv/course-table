package cn.hieu.course_table

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.graphics.drawable.Icon
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.util.Log
import org.json.JSONObject

/**
 * Xiaomi HyperOS focus notification (OS2) and super island (OS3).
 *
 * HyperOS lifts an ordinary notification into a focus notification / super
 * island when its extras carry a `miui.focus.param` JSON payload. This follows
 * the official "OS2/OS3 相同模板" route, so one payload serves both system
 * generations: OS2 shows the focus notification (status bar, lock screen, AOD)
 * and OS3 additionally shows the island (big island + small island).
 *
 * Sending the payload is safe on every device:
 *  - `filterWhenNoPermission` is false, so HyperOS falls back to an ordinary
 *    notification instead of dropping it when the app has no focus permission;
 *  - plain Android and older HyperOS simply ignore the unknown extra.
 *
 * A note on the island field names: they are taken verbatim from the official
 * guide (dev.mi.com/xiaomihyperos "开发指南"). Islands are template driven, so
 * validate the payload against 《小米超级岛通知模板库》 on a real device.
 */
object FocusIsland {
    private const val TAG = "FocusIsland"

    /** Notification extra carrying the island payload. */
    const val PARAM_KEY = "miui.focus.param"

    const val NOTIFICATION_ID = 4242

    private const val CHANNEL_ID = "course_island"
    private const val CHANNEL_NAME = "课程灵动岛"
    private const val CHANNEL_DESCRIPTION = "在灵动岛和焦点通知中显示当前或下一节课程"

    /** `miui.focus.param` must not exceed 3072 bytes. */
    private const val MAX_PARAM_BYTES = 3072

    private const val BUSINESS = "course"
    private const val HIGHLIGHT_COLOR = "#2563EB"

    /**
     * Pictures the payload refers to travel in a separate extras bundle,
     * keyed by name. The island templates need a picture: without one the
     * small island has nothing to draw and SystemUI drops the island.
     */
    private const val PICS_KEY = "miui.focus.pics"
    private const val PIC_ICON = "miui.focus.pic_course"

    /** Everything the notification and the island need, already formatted. */
    data class Content(
        val title: String,
        val summary: String,
        val ticker: String,
        val frontTitle: String,
        val highlight: String,
        val detail: String,
    )

    // ---- capability ----

    /** Platform setting written by HyperOS: 1 = OS1, 2 = OS2, 3 = OS3, 0 = none. */
    fun protocolVersion(context: Context): Int = try {
        Settings.System.getInt(context.contentResolver, "notification_focus_protocol", 0)
    } catch (error: Exception) {
        Log.w(TAG, "notification_focus_protocol unreadable", error)
        0
    }

    /**
     * `persist.sys.feature.island` is a hidden system property, so it needs
     * reflection and can be blocked by the non-SDK interface policy. Fall back
     * to the protocol version, which HyperOS 3 also reports as 3.
     */
    fun supportsIsland(context: Context): Boolean {
        try {
            val systemProperties = Class.forName("android.os.SystemProperties")
            val get = systemProperties.getMethod("get", String::class.java, String::class.java)
            val value = get.invoke(null, "persist.sys.feature.island", "") as? String
            if (!value.isNullOrEmpty()) return value == "true" || value == "1"
        } catch (error: Exception) {
            Log.d(TAG, "persist.sys.feature.island unavailable: ${error.message}")
        }
        return protocolVersion(context) >= 3
    }

    /**
     * Whether the user turned the focus-notification switch on for this app.
     * This is a blocking IPC into SystemUI, so never call it from the tick loop.
     */
    fun hasFocusPermission(context: Context): Boolean = try {
        val extras = Bundle().apply { putString("package", context.packageName) }
        context.contentResolver
            .call(
                Uri.parse("content://miui.statusbar.notification.public"),
                "canShowFocus",
                null,
                extras,
            )
            ?.getBoolean("canShowFocus", false)
            ?: false
    } catch (error: Exception) {
        false
    }

    fun capability(context: Context): Map<String, Any> = mapOf(
        "protocol" to protocolVersion(context),
        "supportsIsland" to supportsIsland(context),
        "hasFocusPermission" to hasFocusPermission(context),
        "manufacturer" to Build.MANUFACTURER,
    )

    // ---- payload ----

    fun buildParam(content: Content): String {
        val textInfo = JSONObject().apply {
            put("frontTitle", content.frontTitle)
            put("title", content.highlight)
            put("content", content.detail)
            put("useHighLight", true)
        }
        val picInfo = JSONObject().apply {
            put("type", 1)
            put("pic", PIC_ICON)
        }
        val island = JSONObject().apply {
            put("islandProperty", 1)
            put("islandTimeout", 3 * 60 * 60)
            // 大岛 A 区：图文信息
            put(
                "bigIslandArea",
                JSONObject().apply {
                    put(
                        "imageTextInfoLeft",
                        JSONObject().apply {
                            put("type", 1)
                            put("picInfo", picInfo)
                            put("textInfo", textInfo)
                        },
                    )
                },
            )
            // 小岛（摘要态）：只放图标，文字由大岛展开时显示
            put(
                "smallIslandArea",
                JSONObject().apply { put("picInfo", picInfo) },
            )
        }
        val payload = JSONObject().apply {
            put(
                "param_v2",
                JSONObject().apply {
                    put("protocol", 1)
                    put("business", BUSINESS)
                    // 首次出现展开，之后更新不再自动展开，避免反复打断用户。
                    put("islandFirstFloat", true)
                    put("enableFloat", false)
                    put("updatable", true)
                    put("reopen", "reopen")
                    // 没有焦点通知权限时退化为普通通知，而不是被过滤掉。
                    put("filterWhenNoPermission", false)
                    put("timeout", 720)
                    // OS2 靠 ticker 显示状态栏文案，OS3 用岛，两者共存。
                    put("ticker", content.ticker)
                    put("aodTitle", content.ticker)
                    put("param_island", island)
                    put(
                        "baseInfo",
                        JSONObject().apply {
                            put("title", content.title)
                            put("content", content.summary)
                            put("colorTitle", HIGHLIGHT_COLOR)
                            put("type", 2)
                        },
                    )
                },
            )
        }.toString()
        val size = payload.toByteArray(Charsets.UTF_8).size
        if (size > MAX_PARAM_BYTES) {
            Log.w(TAG, "focus payload is $size bytes, over the $MAX_PARAM_BYTES limit")
        }
        return payload
    }

    // ---- posting ----

    fun post(context: Context, content: Content, payload: String) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager)
        val pending = launchIntent(context)?.let {
            PendingIntent.getActivity(
                context,
                0,
                it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
        }
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(smallIcon(context))
            .setContentTitle(content.title)
            .setContentText(content.summary)
            .setContentIntent(pending)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setShowWhen(false)
            .build()
        notification.extras.putString(PARAM_KEY, payload)
        notification.extras.putBundle(
            PICS_KEY,
            Bundle().apply {
                putParcelable(PIC_ICON, Icon.createWithResource(context, smallIcon(context)))
            },
        )
        manager.notify(NOTIFICATION_ID, notification)
    }

    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }

    private fun launchIntent(context: Context) =
        context.packageManager.getLaunchIntentForPackage(context.packageName)

    private fun smallIcon(context: Context): Int =
        context.applicationInfo.icon.takeIf { it != 0 } ?: android.R.drawable.ic_dialog_info

    private fun ensureChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply { description = CHANNEL_DESCRIPTION },
        )
    }
}
