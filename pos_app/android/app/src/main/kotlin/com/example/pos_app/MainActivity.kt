package com.example.pos_app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.StatFs
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pos_app/mdm"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val componentName = ComponentName(this, DeviceAdminReceiver::class.java)

            when (call.method) {
                "lockScreen" -> handleLockScreen(dpm, componentName, result)
                "hasDeviceAdminPermission" -> handleHasAdmin(dpm, componentName, result)
                "requestDeviceAdminPermission" -> handleRequestAdmin(result)
                "isKioskModeEnabled" -> result.success(dpm.isLockTaskPermitted(packageName))
                "enableKioskMode" -> handleEnableKiosk(result)
                "disableKioskMode" -> handleDisableKiosk(result)
                "getBatteryInfo" -> handleGetBatteryInfo(result)
                "getStorageInfo" -> handleGetStorageInfo(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleLockScreen(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        result: MethodChannel.Result
    ) {
        if (!dpm.isAdminActive(componentName)) {
            result.error("ADMIN_NOT_ACTIVE", "请先启用设备管理员权限", null)
            return
        }
        try {
            dpm.lockNow()
            result.success(true)
        } catch (e: SecurityException) {
            result.error("LOCK_FAILED", e.message, null)
        }
    }

    private fun handleHasAdmin(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        result: MethodChannel.Result
    ): Boolean {
        val isAdmin = dpm.isAdminActive(componentName)
        result.success(isAdmin)
        return isAdmin
    }

    private fun handleRequestAdmin(result: MethodChannel.Result) {
        try {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                    ComponentName(this@MainActivity, DeviceAdminReceiver::class.java))
                putExtra(DevicePolicyManager.EXTRA_ADD_EXPLANATION, "启用设备管理员权限以使用锁屏、Kiosk模式等功能")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("REQUEST_ADMIN_FAILED", e.message, null)
        }
    }

    private fun handleEnableKiosk(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            startLockTask()
            result.success(true)
        } else {
            result.error("KIOSK_UNSUPPORTED", "此Android版本不支持Kiosk模式", null)
        }
    }

    private fun handleDisableKiosk(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            stopLockTask()
            result.success(true)
        } else {
            result.error("KIOSK_UNSUPPORTED", "此Android版本不支持Kiosk模式", null)
        }
    }

    private fun handleGetStorageInfo(result: MethodChannel.Result) {
        val storageInfo = mutableMapOf<String, Any?>()
        try {
            val stats = StatFs("/data")
            stats.restat("/data")
            val total = stats.totalBytes.toDouble()
            val free = stats.freeBytes.toDouble()
            val totalMemory = Runtime.getRuntime().totalMemory().toDouble()
            val freeMemory = Runtime.getRuntime().freeMemory().toDouble()

            storageInfo["storage_usage"] = if (total > 0) ((total - free) / total * 100).toBigDecimal(2).toDouble() else 0.0
            storageInfo["memory_usage"] = if (totalMemory > 0) ((totalMemory - freeMemory) / totalMemory * 100).toBigDecimal(2).toDouble() else 0.0
        } catch (e: Exception) {
            storageInfo["error"] = e.message
        }
        result.success(storageInfo)
    }

    private fun Double.toBigDecimal(scale: Int) = java.math.BigDecimal(this).setScale(scale, java.math.RoundingMode.HALF_UP)

    private fun handleGetBatteryInfo(result: MethodChannel.Result) {
        val batteryInfo = mutableMapOf<String, Any?>()
        try {
            val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
            if (intent != null) {
                val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
                val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
                val temperature = intent.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, 0)
                val isCharging = intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1)

                val batteryPct = if (level >= 0 && scale > 0) level * 100 / scale else 0
                batteryInfo["level"] = batteryPct
                batteryInfo["temperature"] = temperature / 10.0     // 原始值单位0.1°C
                batteryInfo["is_charging"] = isCharging == BatteryManager.BATTERY_STATUS_CHARGING
                        || isCharging == BatteryManager.BATTERY_STATUS_FULL
            } else {
                batteryInfo["error"] = "无法获取电池信息"
            }
        } catch (e: Exception) {
            batteryInfo["error"] = e.message
        }
        result.success(batteryInfo)
    }
}
