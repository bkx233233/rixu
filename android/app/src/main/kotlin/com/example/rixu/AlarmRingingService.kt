package com.example.rixu

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat

class AlarmRingingService : Service() {
    private var ringtone: Ringtone? = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title") ?: "日程提醒"
        val eventId = intent?.getStringExtra("eventId") ?: ""
        val activity = PendingIntent.getActivity(this, eventId.hashCode(), Intent(this, AlarmActivity::class.java).putExtra("title", title).putExtra("eventId", eventId), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(NotificationChannel("alarm_reminders", "闹铃提醒", NotificationManager.IMPORTANCE_HIGH))
        startForeground(91, NotificationCompat.Builder(this, "alarm_reminders").setSmallIcon(R.mipmap.ic_launcher).setContentTitle("日程开始：$title").setContentText("点击关闭或稍后提醒").setCategory(NotificationCompat.CATEGORY_ALARM).setPriority(NotificationCompat.PRIORITY_MAX).setOngoing(true).setFullScreenIntent(activity, true).setContentIntent(activity).build())
        ringtone = RingtoneManager.getRingtone(this, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))?.also { it.play() }
        (getSystemService(Vibrator::class.java))?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 700, 500), 0))
        return START_NOT_STICKY
    }
    override fun onDestroy() { ringtone?.stop(); getSystemService(Vibrator::class.java)?.cancel(); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
}
