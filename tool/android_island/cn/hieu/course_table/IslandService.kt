package cn.hieu.course_table

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * Foreground service that keeps the HyperOS focus notification / super island in
 * sync with the timetable. It reads the timetable JSON written by the Dart side
 * from FlutterSharedPreferences and re-evaluates the display state every second,
 * so the island keeps working after the Flutter UI is gone.
 *
 * The island itself is rendered by HyperOS from the notification extras (see
 * [FocusIsland]); this service only decides what the island should say.
 *
 * Mirrors lib/reminders.dart — keep DEFAULT_PERIOD_STARTS /
 * DEFAULT_PERIOD_LENGTH_MINUTES in sync with defaultPeriodStartTimes /
 * defaultPeriodLengthMinutes.
 */
class IslandService : Service() {
    companion object {
        const val ACTION_REFRESH = "cn.hieu.course_table.action.REFRESH_ISLAND"
        private const val TAG = "IslandService"
        private const val CHANNEL_ID = "island_service"
        private const val NOTIFICATION_ID = 42
        private const val PREFS_FILE = "FlutterSharedPreferences"
        private const val KEY_TIMETABLE = "flutter.timetable"

        // Minutes since midnight; mirrors defaultPeriodStartTimes in
        // reminders.dart. A timetable may override both via its optional
        // "periodStarts" / "periodLength" fields (作息时间 setting).
        private val DEFAULT_PERIOD_STARTS = intArrayOf(
            480, 535, 600, 655, 840, 895, 960, 1015, 1140, 1195, 1260, 1315,
        )
        private const val DEFAULT_PERIOD_LENGTH_MINUTES = 45
    }

    private data class Course(
        val name: String,
        val weekday: Int, // Dart convention: Monday=1 .. Sunday=7
        val startPeriod: Int,
        val endPeriod: Int,
        val weeks: Set<Int>,
        val room: String,
    )

    private data class Timetable(
        val startDateMillis: Long?, // start-of-day millis of teaching week 1
        val totalWeeks: Int,
        val courses: List<Course>,
        val periodStarts: IntArray = DEFAULT_PERIOD_STARTS,
        val periodLength: Int = DEFAULT_PERIOD_LENGTH_MINUTES,
    )

    private sealed class IslandState {
        data class InClass(val course: Course, val minutesLeft: Int) : IslandState()
        data class UpNext(val course: Course, val secondsLeft: Long) : IslandState()
    }

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var prefs: SharedPreferences
    private var timetable: Timetable? = null
    private var lastPayload: String? = null

    private val prefsListener =
        SharedPreferences.OnSharedPreferenceChangeListener { _, key ->
            if (key == KEY_TIMETABLE) loadTimetable()
        }

    private val tick = object : Runnable {
        override fun run() {
            updateIsland()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        startForegroundWithNotification()
        prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(prefsListener)
        loadTimetable()
        handler.post(tick)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_REFRESH) loadTimetable()
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        if (::prefs.isInitialized) {
            prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)
        }
        FocusIsland.cancel(this)
        super.onDestroy()
    }

    // ---- foreground notification ----
    //
    // HyperOS renders the island from the separate focus notification posted by
    // updateIsland(). This one only keeps the process alive, so it stays minimal
    // and silent.

    private fun startForegroundWithNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "灵动岛运行中",
                    NotificationManager.IMPORTANCE_MIN,
                ),
            )
        }
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pending = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("课表灵动岛运行中")
            .setContentIntent(pending)
            .setOngoing(true)
            .build()
        // FOREGROUND_SERVICE_TYPE_SPECIAL_USE only exists from Android 14.
        // Passing it on 10–13 throws (the manifest type is unknown there and
        // reads as none), which killed the service before the island showed.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    // ---- timetable loading (mirrors lib/models.dart) ----

    private fun loadTimetable() {
        val json = prefs.getString(KEY_TIMETABLE, null)
        timetable = json?.let { parseTimetable(it) }
        lastPayload = null
        Log.d(TAG, "timetable loaded: ${timetable?.courses?.size ?: 0} courses")
    }

    private fun parseTimetable(json: String): Timetable? {
        return try {
            val root = JSONObject(json)
            val startDate = root.optString("startDate")
                .takeIf { it.isNotEmpty() }
                ?.let {
                    SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(it)?.time
                }
            val courses = root.getJSONArray("courses")
            val parsed = ArrayList<Course>(courses.length())
            for (i in 0 until courses.length()) {
                val item = courses.getJSONObject(i)
                val weeksJson = item.getJSONArray("weeks")
                val weeks = HashSet<Int>(weeksJson.length())
                for (w in 0 until weeksJson.length()) weeks.add(weeksJson.getInt(w))
                parsed.add(
                    Course(
                        name = item.getString("name"),
                        weekday = item.getInt("weekday"),
                        startPeriod = item.getInt("startPeriod"),
                        endPeriod = item.getInt("endPeriod"),
                        weeks = weeks,
                        room = item.optString("room"),
                    ),
                )
            }
            val startsJson = root.optJSONArray("periodStarts")
            val starts = if (startsJson != null && startsJson.length() > 0) {
                IntArray(startsJson.length()) { startsJson.getInt(it) }
            } else {
                DEFAULT_PERIOD_STARTS
            }
            val length = root.optInt("periodLength", DEFAULT_PERIOD_LENGTH_MINUTES)
            Timetable(startDate, root.getInt("totalWeeks"), parsed, starts, length)
        } catch (error: Exception) {
            Log.e(TAG, "failed to parse timetable", error)
            null
        }
    }

    // ---- scheduling logic (mirrors lib/reminders.dart islandState) ----

    private fun weekFor(date: Calendar, table: Timetable): Int {
        // No start date: the week is unknown, so show nothing rather than
        // treating every day as week 1 (mirrors notification_service.dart).
        val start = table.startDateMillis ?: return 0
        val dayStart = startOfDay(date.timeInMillis)
        val diffDays = ((dayStart - start) / 86_400_000L).toInt()
        // Unclamped: outside the semester no week matches, so no courses show.
        return Math.floorDiv(diffDays, 7) + 1
    }

    private fun dartWeekday(date: Calendar): Int {
        // Calendar: Sunday=1..Saturday=7 → Dart: Monday=1..Sunday=7
        val weekday = date.get(Calendar.DAY_OF_WEEK)
        return if (weekday == Calendar.SUNDAY) 7 else weekday - 1
    }

    private fun coursesForToday(now: Calendar, table: Timetable): List<Course> {
        val week = weekFor(now, table)
        val weekday = dartWeekday(now)
        return table.courses
            .filter {
                it.weekday == weekday &&
                    it.weeks.contains(week) &&
                    it.startPeriod >= 1 &&
                    it.endPeriod <= table.periodStarts.size
            }
            .sortedBy { it.startPeriod }
    }

    private fun computeState(now: Calendar): IslandState? {
        val table = timetable ?: return null
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val courses = coursesForToday(now, table)

        for (course in courses) {
            val start = table.periodStarts[course.startPeriod - 1]
            val end = table.periodStarts[course.endPeriod - 1] + table.periodLength
            if (nowMinutes >= start && nowMinutes < end) {
                val secondsLeft = (end - nowMinutes) * 60L - now.get(Calendar.SECOND)
                val minutesLeft = ((secondsLeft + 59) / 60).toInt().coerceIn(0, 9999)
                return IslandState.InClass(course, minutesLeft)
            }
        }
        val next = courses.firstOrNull { table.periodStarts[it.startPeriod - 1] > nowMinutes }
            ?: return null
        val startMinutes = table.periodStarts[next.startPeriod - 1]
        val secondsLeft =
            (startMinutes - nowMinutes) * 60L - now.get(Calendar.SECOND)
        return IslandState.UpNext(next, secondsLeft)
    }

    // ---- island content ----

    private fun periodRange(course: Course): String =
        "第${course.startPeriod}-${course.endPeriod}节"

    /**
     * The island lays text out in small blocks, so keep this short. Minute
     * precision (rounded up) on purpose: the payload then changes once a
     * minute instead of every second, so SystemUI is not asked to re-render
     * (and re-animate) the island 60 times a minute.
     */
    private fun compact(seconds: Long): String {
        val minutes = ((seconds.coerceAtLeast(0) + 59) / 60)
        return when {
            minutes >= 60 -> "${minutes / 60}小时${minutes % 60}分"
            else -> "${minutes.coerceAtLeast(1)}分钟"
        }
    }

    private fun contentFor(state: IslandState?): FocusIsland.Content? = when (state) {
        is IslandState.InClass -> {
            val course = state.course
            val place = course.room.ifEmpty { periodRange(course) }
            FocusIsland.Content(
                title = course.name,
                summary = "${periodRange(course)} · $place · 还剩${state.minutesLeft}分钟",
                ticker = "上课中 · ${course.name} · 还剩${state.minutesLeft}分钟",
                frontTitle = "上课中",
                highlight = "剩${state.minutesLeft}分钟",
                detail = place,
            )
        }

        is IslandState.UpNext -> {
            val course = state.course
            val place = course.room.ifEmpty { periodRange(course) }
            FocusIsland.Content(
                title = course.name,
                summary = "${periodRange(course)} · $place · ${compact(state.secondsLeft)}后开始",
                ticker = "下一节 · ${course.name} · ${compact(state.secondsLeft)}后",
                frontTitle = "下一节",
                highlight = compact(state.secondsLeft),
                detail = place,
            )
        }

        null -> null
    }

    /**
     * Re-posts the focus notification only when the rendered payload changes, so
     * the per-second tick does not spam SystemUI while nothing is moving.
     */
    private fun updateIsland() {
        val content = contentFor(computeState(Calendar.getInstance()))
        if (content == null) {
            if (lastPayload != null) {
                FocusIsland.cancel(this)
                lastPayload = null
            }
            return
        }
        val payload = FocusIsland.buildParam(content)
        if (payload == lastPayload) return
        lastPayload = payload
        FocusIsland.post(this, content, payload)
    }

    // ---- helpers ----

    private fun startOfDay(millis: Long): Long {
        val calendar = Calendar.getInstance()
        calendar.timeInMillis = millis
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        calendar.set(Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }
}
