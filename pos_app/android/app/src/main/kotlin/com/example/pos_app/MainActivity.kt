package com.example.pos_app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.Uri
import android.net.wifi.ScanResult
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.pos_app/mdm"
    private val SERVICE_CHANNEL = "com.example.pos_app/mdm_service"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ========== 自启动：开机后由 BootReceiver 触发，保障 Flutter 引擎初始化 ==========
        val fromBoot = intent?.getBooleanExtra(BootReceiver.EXTRA_FROM_BOOT, false) ?: false
        if (fromBoot) {
            android.util.Log.d("MainActivity", "由开机广播启动，保持后台运行")
        }

        // 对于已激活设备，自动启动前台保活服务（即使从 BootReceiver 启动）
        // 心跳由 Flutter MdmService 的 initHeartbeat 控制
        MdmForegroundService.start(this)

        // ========== MethodChannel: MDM 核心命令 ==========
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
            val componentName = DeviceAdminReceiver.getComponentName(this)
            val args = call.arguments as? Map<String, Any?> ?: emptyMap()

            when (call.method) {
                // === Device Admin 基础能力 ===
                "lockScreen" -> handleLockScreen(dpm, componentName, result)
                "hasDeviceAdminPermission" -> handleHasAdmin(dpm, componentName, result)
                "requestDeviceAdminPermission" -> handleRequestAdmin(result)
                "isKioskModeEnabled" -> result.success(dpm.isLockTaskPermitted(packageName))
                "enableKioskMode" -> handleEnableKiosk(result)
                "disableKioskMode" -> handleDisableKiosk(result)
                "getBatteryInfo" -> handleGetBatteryInfo(result)
                "getStorageInfo" -> handleGetStorageInfo(result)

                // === Device Owner 能力 ===
                "isDeviceOwner" -> handleIsDeviceOwner(dpm, result)
                "setLockTaskPackages" -> handleSetLockTaskPackages(dpm, componentName, args, result)
                "isLockTaskAllowed" -> handleIsLockTaskAllowed(dpm, args, result)
                "setUninstallBlocked" -> handleSetUninstallBlocked(dpm, componentName, args, result)
                "setKeyguardDisabled" -> handleSetKeyguardDisabled(dpm, componentName, args, result)
                "setStatusBarDisabled" -> handleSetStatusBarDisabled(dpm, componentName, args, result)
                "addUserRestriction" -> handleAddUserRestriction(dpm, componentName, args, result)
                "removeUserRestriction" -> handleClearUserRestriction(dpm, componentName, args, result)
                "wipeData" -> handleWipeData(dpm, result)
                "reboot" -> handleReboot(dpm, componentName, result)
                "setCameraDisabled" -> handleSetCameraDisabled(dpm, componentName, args, result)

                else -> result.notImplemented()
            }
        }

        // ========== MethodChannel: 硬件信息 ==========
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.pos_app/hardware").setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidNativeId" -> {
                    val androidId = android.provider.Settings.Secure.getString(
                        contentResolver,
                        android.provider.Settings.Secure.ANDROID_ID
                    ) ?: "unknown"
                    result.success(androidId)
                }
                else -> result.notImplemented()
            }
        }

        // ========== MethodChannel: 保活服务控制 ==========
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    MdmForegroundService.start(this)
                    result.success(true)
                }
                "stopForegroundService" -> {
                    MdmForegroundService.stop(this)
                    result.success(false)
                }
                "isServiceRunning" -> {
                    result.success(MdmForegroundService.isRunning())
                }
                "acquireWakeLock" -> {
                    MdmForegroundService.acquireWakeLock(this)
                    result.success(true)
                }
                "releaseWakeLock" -> {
                    MdmForegroundService.releaseWakeLock()
                    result.success(true)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    val intent = Intent(
                        Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                        Uri.parse("package:$packageName")
                    ).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }
                "connectToWifi" -> {
                    val ssid = (call.arguments as? Map<String, Any?>)?.get("ssid") as? String ?: ""
                    val password = (call.arguments as? Map<String, Any?>)?.get("password") as? String ?: ""
                    handleConnectToWifi(ssid, password, result)
                }
                "scanWifi" -> {
                    handleScanWifi(result)
                }
                "isWifiEnabled" -> {
                    val wifiManager = getSystemService(Context.WIFI_SERVICE) as WifiManager
                    result.success(wifiManager.isWifiEnabled)
                }
                "isWifiConnected" -> {
                    val wifiManager = getSystemService(Context.WIFI_SERVICE) as WifiManager
                    val info = wifiManager.connectionInfo
                    result.success(info != null && info.ipAddress != 0)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // 处理 BootReceiver 二次启动（如果 Activity 已在运行）
        val fromBoot = intent.getBooleanExtra(BootReceiver.EXTRA_FROM_BOOT, false)
        if (fromBoot) {
            android.util.Log.d("MainActivity", "收到开机广播二次启动 Intent")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Activity 销毁时保活服务继续运行（不停止）
        android.util.Log.d("MainActivity", "Activity 销毁，前台保活服务继续在后台运行")
    }

    // ========== Device Admin 方法（已有） ==========

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
    ) {
        result.success(dpm.isAdminActive(componentName))
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
                batteryInfo["temperature"] = temperature / 10.0
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

    // ========== Device Owner 新方法 ==========

    private fun handleIsDeviceOwner(
        dpm: DevicePolicyManager,
        result: MethodChannel.Result
    ) {
        result.success(dpm.isDeviceOwnerApp(packageName))
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleSetLockTaskPackages(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        args: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        if (!dpm.isDeviceOwnerApp(packageName)) {
            result.error("NOT_DEVICE_OWNER", "需要 Device Owner 权限", null)
            return
        }
        val packages = (args["packages"] as? List<String>) ?: listOf(packageName)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                dpm.setLockTaskPackages(componentName, packages.toTypedArray())
                result.success(true)
            } else {
                result.error("UNSUPPORTED", "此Android版本不支持锁任务", null)
            }
        } catch (e: Exception) {
            result.error("SET_LOCKTASK_FAILED", e.message, null)
        }
    }

    private fun handleIsLockTaskAllowed(
        dpm: DevicePolicyManager,
        args: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        val pkg = args["package"] as? String ?: packageName
        result.success(dpm.isLockTaskPermitted(pkg))
    }

    private fun handleSetUninstallBlocked(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        args: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        if (!dpm.isDeviceOwnerApp(packageName)) {
            result.error("NOT_DEVICE_OWNER", "需要 Device Owner 权限", null)
            return
        }
        val blocked = (args["blocked"] as? Boolean) ?: true
        val pkg = args["package"] as? String ?: packageName
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                dpm.setUninstallBlocked(componentName, pkg, blocked)
                result.success(true)
            } else {
                result.error("UNSUPPORTED", "此Android版本不支持防卸载", null)
            }
        } catch (e: Exception) {
            result.error("SET_UNINSTALL_BLOCKED_FAILED", e.message, null)
        }
    }

    private fun handleSetKeyguardDisabled(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        args: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        if (!dpm.isDeviceOwnerApp(packageName)) {
            result.error("NOT_DEVICE_OWNER", "需要 Device Owner 权限", null)
            return
        }
        val disabled = (args["disabled"] as? Boolean) ?: true
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                dpm.setKeyguardDisabled(componentName, disabled)
                result.success(true)
            } else {
                result.error("UNSUPPORTED", "此Android版本不支持", null)
            }
        } catch (e: Exception) {
            result.error("SET_KEYGUARD_FAILED", e.message, null)
        }
    }

    private fun handleSetStatusBarDisabled(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        args: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        if (!dpm.isDeviceOwnerApp(packageName)) {
            result.error("NOT_DEVICE_OWNER", "需要 Device Owner 权限", null)
            return
        }
        val disabled = (args["disabled"] as? Boolean) ?: true
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                dpm.setStatusBarDisabled(componentName, disabled)
                result.success(true)
            } else {
                result.error("UNSUPPORTED", "此Android版本不支持", null)
            }
        } catch (e: Exception) {
            result.error("SET_STATUSBAR_FAILED", e.message, null)
        }
    }

    private fun handleAddUserRestriction(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        args: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        if (!dpm.isDeviceOwnerApp(packageName)) {
            result.error("NOT_DEVICE_OWNER", "需要 Device Owner 权限", null)
            return
        }
        val restriction = args["restriction"] as? String
        if (restriction == null) {
            result.error("MISSING_PARAM", "缺少 restriction 参数", null)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                dpm.addUserRestriction(componentName, restriction)
                result.success(true)
            } else {
                result.error("UNSUPPORTED", "此Android版本不支持", null)
            }
        } catch (e: Exception) {
            result.error("ADD_RESTRICTION_FAILED", e.message, null)
        }
    }

    private fun handleClearUserRestriction(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        args: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        if (!dpm.isDeviceOwnerApp(packageName)) {
            result.error("NOT_DEVICE_OWNER", "需要 Device Owner 权限", null)
            return
        }
        val restriction = args["restriction"] as? String
        if (restriction == null) {
            result.error("MISSING_PARAM", "缺少 restriction 参数", null)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                dpm.clearUserRestriction(componentName, restriction)
                result.success(true)
            } else {
                result.error("UNSUPPORTED", "此Android版本不支持", null)
            }
        } catch (e: Exception) {
            result.error("REMOVE_RESTRICTION_FAILED", e.message, null)
        }
    }

    private fun handleWipeData(
        dpm: DevicePolicyManager,
        result: MethodChannel.Result
    ) {
        try {
            dpm.wipeData(0)
            result.success(true)
        } catch (e: Exception) {
            result.error("WIPE_FAILED", e.message, null)
        }
    }

    private fun handleReboot(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        result: MethodChannel.Result
    ) {
        if (!dpm.isDeviceOwnerApp(packageName)) {
            result.error("NOT_DEVICE_OWNER", "需要 Device Owner 权限", null)
            return
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                dpm.reboot(componentName)
                // reboot 调用后不会返回，所以此处不会执行到
                result.success(true)
            } else {
                // Android 8.x 及以下使用 Shell 重启（需 system 权限或 root）
                try {
                    Runtime.getRuntime().exec(arrayOf("su", "-c", "reboot"))
                    result.success(true)
                } catch (e: SecurityException) {
                    result.error("UNSUPPORTED", "此Android版本不支持远程重启（需要 Android 9+ 或 root 权限）", null)
                }
            }
        } catch (e: Exception) {
            result.error("REBOOT_FAILED", e.message, null)
        }
    }

    @Suppress("UNCHECKED_CAST")
    private fun handleSetCameraDisabled(
        dpm: DevicePolicyManager,
        componentName: ComponentName,
        args: Map<String, Any?>,
        result: MethodChannel.Result
    ) {
        if (!dpm.isDeviceOwnerApp(packageName)) {
            result.error("NOT_DEVICE_OWNER", "需要 Device Owner 权限", null)
            return
        }
        val disabled = (args["disabled"] as? Boolean) ?: true
        try {
            dpm.setCameraDisabled(componentName, disabled)
            result.success(true)
        } catch (e: Exception) {
            result.error("SET_CAMERA_FAILED", e.message, null)
        }
    }

    // ========== WiFi 连接（配网引导） ==========

    @Suppress("DEPRECATION")
    private fun handleConnectToWifi(
        ssid: String,
        password: String,
        result: MethodChannel.Result
    ) {
        if (ssid.isEmpty()) {
            android.util.Log.e("WiFiConnect", "SSID 为空")
            result.error("MISSING_SSID", "SSID 不能为空", null)
            return
        }

        android.util.Log.d("WiFiConnect", "开始连接 WiFi: $ssid, SDK=${Build.VERSION.SDK_INT}")

        try {
            val wifiManager = getSystemService(Context.WIFI_SERVICE) as WifiManager
            android.util.Log.d("WiFiConnect", "WiFi 开启状态: ${wifiManager.isWifiEnabled}")

            if (!wifiManager.isWifiEnabled) {
                result.error("WIFI_DISABLED", "WiFi 未开启", null)
                return
            }

            // ========== 全版本优先使用 WifiManager.addNetwork（可靠直接） ==========
            try {
                val netId = tryAddNetwork(ssid, password, wifiManager)
                if (netId != -1) {
                    wifiManager.enableNetwork(netId, true)
                    wifiManager.reconnect()
                    android.util.Log.d("WiFiConnect", "enableNetwork + reconnect 完成, netId=$netId")
                    verifyConnection(ssid, wifiManager, result)
                } else {
                    android.util.Log.w("WiFiConnect", "addNetwork 返回 -1")
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        connectWithSuggestion(ssid, password, wifiManager, result)
                    } else {
                        result.error("WIFI_ADD_FAILED", "添加 WiFi 网络失败", null)
                    }
                }
            } catch (e: Exception) {
                android.util.Log.e("WiFiConnect", "addNetwork 异常", e)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    connectWithSuggestion(ssid, password, wifiManager, result)
                } else {
                    result.error("WIFI_EXCEPTION", "WiFi 连接异常: ${e.message}", null)
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("WiFiConnect", "连接异常", e)
            result.error("WIFI_EXCEPTION", "WiFi 连接异常: ${e.message}", null)
        }
    }

    @Suppress("DEPRECATION")
    private fun connectWithSuggestion(
        ssid: String,
        password: String,
        wifiManager: WifiManager,
        result: MethodChannel.Result
    ) {
        try {
            val builder = android.net.wifi.WifiNetworkSuggestion.Builder()
                .setSsid(ssid)
            if (password.isNotEmpty()) {
                builder.setWpa2Passphrase(password)
            }
            // 空密码 = 开放网络，不设置密码即可

            val suggestion = builder.build()
            android.util.Log.d("WiFiConnect", "添加 WifiNetworkSuggestion")

            val status = wifiManager.addNetworkSuggestions(listOf(suggestion))
            android.util.Log.d("WiFiConnect", "addNetworkSuggestions 返回: $status")

            if (status == WifiManager.STATUS_NETWORK_SUGGESTIONS_SUCCESS) {
                // 系统会自动连接，后台线程等待验证
                Thread {
                    try {
                        for (i in 1..15) {
                            Thread.sleep(1000)
                            try {
                                val info = wifiManager.connectionInfo
                                val connectedSsid = info?.ssid?.trim('"') ?: ""
                                android.util.Log.d("WiFiConnect", "验证中[$i/15]: ssid=$connectedSsid, ip=${info?.ipAddress}")
                                if (connectedSsid == ssid || info?.ipAddress != 0) {
                                    android.util.Log.d("WiFiConnect", "连接验证成功")
                                    runOnUiThread { result.success(true) }
                                    return@Thread
                                }
                            } catch (e: SecurityException) {
                                android.util.Log.d("WiFiConnect", "无位置权限获取 connectionInfo，假设成功")
                                runOnUiThread { result.success(true) }
                                return@Thread
                            }
                        }
                        android.util.Log.w("WiFiConnect", "连接验证超时(15s)，但仍返回成功")
                        runOnUiThread { result.success(true) }
                    } catch (e: Exception) {
                        android.util.Log.e("WiFiConnect", "验证线程异常", e)
                        runOnUiThread { result.error("WIFI_VERIFY_FAILED", "连接验证失败: ${e.message}", null) }
                    }
                }.start()
            } else {
                android.util.Log.w("WiFiConnect", "addNetworkSuggestions 失败，回退到 Specifier")
                tryConnectWithSpecifier(ssid, password, result, wifiManager)
            }
        } catch (e: Exception) {
            android.util.Log.e("WiFiConnect", "Suggestion 异常", e)
            tryConnectWithSpecifier(ssid, password, result, wifiManager)
        }
    }

    @Suppress("DEPRECATION")
    private fun tryAddNetwork(
        ssid: String,
        password: String,
        wifiManager: WifiManager
    ): Int {
        try {
            wifiManager.configuredNetworks
                .firstOrNull { it.SSID == "\"$ssid\"" }
                ?.networkId
                ?.let { id ->
                    wifiManager.removeNetwork(id)
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                        wifiManager.saveConfiguration()
                    }
                    android.util.Log.d("WiFiConnect", "已删除旧配置: $id")
                }
        } catch (e: SecurityException) {
            android.util.Log.d("WiFiConnect", "无权限读取已保存网络，跳过删除")
        }

        val wifiConfig = WifiConfiguration().apply {
            SSID = "\"$ssid\""
            if (password.isNotEmpty()) {
                preSharedKey = "\"$password\""
            } else {
                allowedKeyManagement.set(WifiConfiguration.KeyMgmt.NONE)
            }
            status = WifiConfiguration.Status.ENABLED
        }

        val netId = wifiManager.addNetwork(wifiConfig)
        android.util.Log.d("WiFiConnect", "addNetwork 返回: $netId")
        return netId
    }

    @Suppress("DEPRECATION")
    private fun verifyConnection(
        ssid: String,
        wifiManager: WifiManager,
        result: MethodChannel.Result
    ) {
        Thread {
            try {
                for (i in 1..10) {
                    Thread.sleep(1000)
                    try {
                        val info = wifiManager.connectionInfo ?: continue
                        android.util.Log.d("WiFiConnect", "验证[$i/10]: ssid=${info.ssid}, ip=${info.ipAddress}")
                        if (info.ipAddress != 0) {
                            android.util.Log.d("WiFiConnect", "连接成功, ip=${info.ipAddress}")
                            runOnUiThread { result.success(true) }
                            return@Thread
                        }
                    } catch (e: SecurityException) {
                        android.util.Log.d("WiFiConnect", "无权限获取连接信息，假设成功")
                        runOnUiThread { result.success(true) }
                        return@Thread
                    }
                }
                android.util.Log.w("WiFiConnect", "验证超时(10s)，无 IP 地址")
                runOnUiThread { result.error("WIFI_NO_IP", "WiFi 已连接但未分配到 IP 地址", null) }
            } catch (e: Exception) {
                android.util.Log.e("WiFiConnect", "验证异常", e)
                runOnUiThread { result.error("WIFI_VERIFY_FAILED", "${e.message}", null) }
            }
        }.start()
    }

    @Suppress("DEPRECATION")
    private fun tryConnectWithSpecifier(
        ssid: String,
        password: String,
        result: MethodChannel.Result,
        wifiManager: WifiManager
    ) {
        android.util.Log.d("WiFiConnect", "回退到 WifiNetworkSpecifier")
        val specifierBuilder = android.net.wifi.WifiNetworkSpecifier.Builder()
            .setSsid(ssid)
        if (password.isNotEmpty()) {
            specifierBuilder.setWpa2Passphrase(password)
        }
        val specifier = specifierBuilder.build()

        val networkRequest = NetworkRequest.Builder()
            .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
            .setNetworkSpecifier(specifier)
            .build()

        val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager

        val callback = object : ConnectivityManager.NetworkCallback() {
            private var handled = false

            override fun onAvailable(network: Network) {
                if (handled) return; handled = true
                android.util.Log.d("WiFiConnect", "Specifier 连接成功: $ssid")
                connectivityManager.bindProcessToNetwork(network)
                runOnUiThread { result.success(true) }
            }

            override fun onUnavailable() {
                if (handled) return; handled = true
                android.util.Log.e("WiFiConnect", "Specifier 连接失败: $ssid")
                runOnUiThread { result.error("WIFI_FAILED", "WiFi 连接失败，请检查密码", null) }
            }
        }

        connectivityManager.requestNetwork(networkRequest, callback)
    }

    // ========== WiFi 扫描 ==========

    private fun handleScanWifi(result: MethodChannel.Result) {
        Thread {
            try {
                val wifiManager = getSystemService(Context.WIFI_SERVICE) as WifiManager

                if (!wifiManager.isWifiEnabled) {
                    runOnUiThread {
                        result.error("WIFI_DISABLED", "WiFi 未开启", null)
                    }
                    return@Thread
                }

                var cachedResults = wifiManager.scanResults
                if (cachedResults.any { it.SSID.isNotEmpty() }) {
                    try { wifiManager.startScan() } catch (_: Exception) {}
                    val networks = formatScanResults(cachedResults)
                    runOnUiThread { result.success(networks) }
                    return@Thread
                }

                try { wifiManager.startScan() } catch (_: Exception) {}

                for (i in 1..12) {
                    Thread.sleep(500)
                    cachedResults = wifiManager.scanResults
                    if (cachedResults.any { it.SSID.isNotEmpty() }) {
                        val networks = formatScanResults(cachedResults)
                        runOnUiThread { result.success(networks) }
                        return@Thread
                    }
                }

                runOnUiThread {
                    result.error("SCAN_NO_RESULTS", "扫描完成，未发现 WiFi 网络", null)
                }
            } catch (e: Exception) {
                runOnUiThread {
                    result.error("SCAN_FAILED", "WiFi 扫描失败: ${e.message}", null)
                }
            }
        }.start()
    }

    private fun formatScanResults(results: List<ScanResult>): List<Map<String, Any>> {
        return results
            .distinctBy { it.SSID }
            .filter { it.SSID.isNotEmpty() }
            .map { scanResult ->
                val caps = scanResult.capabilities
                val isOpen = !caps.contains("WPA") && !caps.contains("WEP")
                mapOf(
                    "ssid" to scanResult.SSID,
                    "level" to scanResult.level,
                    "capabilities" to caps,
                    "isOpen" to isOpen,
                )
            }
    }
}
