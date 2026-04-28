package com.example.pos_app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class DeviceAdminReceiver : android.app.admin.DeviceAdminReceiver() {
    companion object {
        private const val TAG = "DeviceAdminReceiver"

        fun getComponentName(context: Context): ComponentName {
            return ComponentName(context, DeviceAdminReceiver::class.java)
        }
    }

    override fun onEnabled(context: Context, intent: Intent) {
        super.onEnabled(context, intent)
        Log.d(TAG, "设备管理员权限已启用")
    }

    override fun onDisabled(context: Context, intent: Intent) {
        super.onDisabled(context, intent)
        Log.d(TAG, "设备管理员权限已禁用")
    }

    override fun onProfileProvisioningComplete(context: Context, intent: Intent) {
        super.onProfileProvisioningComplete(context, intent)
        Log.d(TAG, "Device Owner 配置完成")

        // provisioning 完成后，默认启用防卸载和锁任务
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        val comp = getComponentName(context)

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                // 将自身加入锁任务白名单
                dpm.setLockTaskPackages(comp, arrayOf(context.packageName))
                Log.d(TAG, "已将自己加入锁任务白名单")
            }
        } catch (e: Exception) {
            Log.e(TAG, "设置锁任务白名单失败: ${e.message}")
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                // 禁止卸载本应用
                dpm.setUninstallBlocked(comp, context.packageName, true)
                Log.d(TAG, "已启用防卸载")
            }
        } catch (e: Exception) {
            Log.e(TAG, "设置防卸载失败: ${e.message}")
        }
    }
}
