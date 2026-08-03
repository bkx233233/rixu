package com.example.rixu

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class AlarmActivity : Activity() {
    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        setShowWhenLocked(true); setTurnScreenOn(true)
        val title = intent.getStringExtra("title") ?: "日程提醒"; val eventId = intent.getStringExtra("eventId") ?: ""
        val layout = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL; gravity = Gravity.CENTER; setPadding(48, 48, 48, 48); setBackgroundColor(Color.rgb(20, 108, 90)) }
        layout.addView(TextView(this).apply { text = "日程开始"; textSize = 20f; setTextColor(Color.WHITE); gravity = Gravity.CENTER })
        layout.addView(TextView(this).apply { text = title; textSize = 30f; setTextColor(Color.WHITE); gravity = Gravity.CENTER; setPadding(0, 28, 0, 40) })
        layout.addView(Button(this).apply { text = "关闭"; setOnClickListener { stopService(android.content.Intent(this@AlarmActivity, AlarmRingingService::class.java)); AlarmRegistry.cancel(this@AlarmActivity, eventId); finish() } })
        layout.addView(Button(this).apply { text = "5 分钟后提醒"; setOnClickListener { stopService(android.content.Intent(this@AlarmActivity, AlarmRingingService::class.java)); AlarmRegistry.schedule(this@AlarmActivity, eventId, title, System.currentTimeMillis() + 5 * 60 * 1000); finish() } })
        setContentView(layout)
    }
}
