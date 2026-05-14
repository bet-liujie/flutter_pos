package com.example.pos_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log

/**
 * MDM 前台保活服务
 *
 * 通过前台服务（持久通知）提升进程优先级，确保心跳上报和命令轮询持续运行。
 * 作为 Device Owner 应用，被系统杀死后会自动重启（START_STICKY）。
 * 部署到 BSP 层后，android:persistent="true" 保证系统启动即运行。
 */
class MdmForegroundService : Service() {
    companion object {
        const val CHANNEL_ID = "mdm_foreground_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_START = "com.example.pos_app.ACTION_START_MDM"
        const val ACTION_STOP = "com.example.pos_app.ACTION_STOP_MDM"
        const val TAG = "MdmForegroundService"

        private var wakeLock: PowerManager.WakeLock? = null
        private var isRunning = false

        fun isRunning(): Boolean = isRunning

        /** 启动前台保活服务 */
        fun start(context: Context) {
            val intent = Intent(context, MdmForegroundService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        /** 停止前台保活服务 */
        fun stop(context: Context) {
            val intent = Intent(context, MdmForegroundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }

        /** 获取 CPU WakeLock（心跳上报期间持有，完成后释放） */
        fun acquireWakeLock(context: Context) {
            if (wakeLock == null) {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                wakeLock = pm.newWakeLock(
                    PowerManager.PARTIAL_WAKE_LOCK,
                    "mdm:heartbeat_wakelock"
                ).apply {
                    setReferenceCounted(false)
                }
            }
            wakeLock?.acquire(10 * 60 * 1000L) // 最长持有 10 分钟，防止异常未释放
        }

        /** 释放 WakeLock */
        fun releaseWakeLock() {
            wakeLock?.let {
                if (it.isHeld) {
                    it.release()
                }
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                isRunning = true
                val notification = buildNotification()
                startForeground(NOTIFICATION_ID, notification)
                acquireWakeLock(this)
                Log.d(TAG, "前台保活服务已启动，进程优先级提升")
            }
            ACTION_STOP -> {
                isRunning = false
                releaseWakeLock()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
                Log.d(TAG, "前台保活服务已停止")
            }
        }
        // START_STICKY：进程被杀死后自动重启（仅重启 Service，Intent 为 null）
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        releaseWakeLock()
    }

    // ========== 通知渠道与通知 ==========

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MDM 后台服务",
                NotificationManager.IMPORTANCE_MIN // 低优先级，不弹窗无声音
            ).apply {
                description = "MDM 心跳上报与远程命令保活服务"
                setShowBadge(false)
                enableLights(false)
                enableVibration(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        // 点击通知回到主界面
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("MDM 服务运行中")
                .setContentText("设备管理与远程命令服务正常运行")
                .setSmallIcon(android.R.drawable.ic_menu_manage)
                .setContentIntent(pendingIntent)
                .setOngoing(true) // 不可滑动移除
                .setPriority(Notification.PRIORITY_MIN)
                .build()
        } else {
            Notification.Builder(this)
                .setContentTitle("MDM 服务运行中")
                .setContentText("设备管理与远程命令服务正常运行")
                .setSmallIcon(android.R.drawable.ic_menu_manage)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(Notification.PRIORITY_MIN)
                .build()
        }
    }
}
