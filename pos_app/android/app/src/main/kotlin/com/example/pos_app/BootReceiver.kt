package com.example.pos_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * 开机自启广播接收器
 *
 * 监听系统开机完成广播，自动启动 MDM 前台保活服务和主 Activity。
 * 确保设备重启后 MDM 功能（心跳上报、命令轮询）无需用户干预即可恢复。
 *
 * BSP 场景：应用作为系统预装 App 时，即使未启用 Device Owner，
 * 系统启动后也会自动分发 BOOT_COMPLETED 广播，实现无感自启。
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return

        // 处理系统开机完成及快速启动（某些 OEM）
        when (action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {

                Log.d(TAG, "系统启动完成 (action=$action)，启动 MDM 保活服务")

                // 1. 启动前台保活服务（提升进程优先级）
                MdmForegroundService.start(context)

                // 2. 启动主 Activity（初始化 Flutter 引擎，加载 DPC 策略）
                //    使用 NEW_TASK + SINGLE_TOP 避免创建多个实例
                val launchIntent = Intent(context, MainActivity::class.java).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                    putExtra(EXTRA_FROM_BOOT, true)
                }
                context.startActivity(launchIntent)
            }
        }
    }

    companion object {
        const val TAG = "BootReceiver"
        const val EXTRA_FROM_BOOT = "from_boot"
    }
}
