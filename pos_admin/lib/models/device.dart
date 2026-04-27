class Device {
  final String deviceId;
  final int merchantId;
  final String status;
  final bool online;
  final DateTime? lastActiveAt;
  final double? storageUsage;
  final double? memoryUsage;
  final String? networkType;
  final String? appVersion;
  final double? latitude;
  final double? longitude;
  final DateTime? lastHeartbeatAt;

  Device({
    required this.deviceId,
    required this.merchantId,
    required this.status,
    required this.online,
    this.lastActiveAt,
    this.storageUsage,
    this.memoryUsage,
    this.networkType,
    this.appVersion,
    this.latitude,
    this.longitude,
    this.lastHeartbeatAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      deviceId: json['device_id'] as String,
      merchantId: int.tryParse('${json['merchant_id']}') ?? 0,
      status: json['status'] as String? ?? 'unknown',
      online: json['online'] as bool? ?? false,
      lastActiveAt: _parseDateTime(json['last_active_at']),
      storageUsage: _parseDouble(json['storage_usage']),
      memoryUsage: _parseDouble(json['memory_usage']),
      networkType: json['network_type'] as String?,
      appVersion: json['app_version'] as String?,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      lastHeartbeatAt: _parseDateTime(json['last_heartbeat_at']),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  String get statusLabel {
    switch (status) {
      case 'active':
        return '正常';
      case 'suspended':
        return '已暂停';
      case 'lost':
        return '丢失';
      case 'retired':
        return '已退役';
      default:
        return status;
    }
  }
}

class DeviceDetail {
  final String deviceId;
  final int merchantId;
  final String status;
  final DateTime? lastActiveAt;
  final List<PolicyInfo> policies;
  final List<CommandInfo> pendingCommands;

  DeviceDetail({
    required this.deviceId,
    required this.merchantId,
    required this.status,
    this.lastActiveAt,
    this.policies = const [],
    this.pendingCommands = const [],
  });

  factory DeviceDetail.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return DeviceDetail(
      deviceId: data['device_id'] as String? ?? '',
      merchantId: int.tryParse('${data['merchant_id']}') ?? 0,
      status: data['status'] as String? ?? 'unknown',
      lastActiveAt: Device._parseDateTime(data['last_active_at']),
      policies: (data['policies'] as List?)
              ?.map((e) => PolicyInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      pendingCommands: (data['pending_commands'] as List?)
              ?.map((e) => CommandInfo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class PolicyInfo {
  final int id;
  final String policyName;
  final String policyData;
  final int version;
  final String bindStatus;

  PolicyInfo({
    required this.id,
    required this.policyName,
    required this.policyData,
    required this.version,
    required this.bindStatus,
  });

  factory PolicyInfo.fromJson(Map<String, dynamic> json) {
    return PolicyInfo(
      id: json['id'] as int? ?? 0,
      policyName: json['policy_name'] as String? ?? '',
      policyData: json['policy_data'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      bindStatus: json['bind_status'] as String? ?? 'unknown',
    );
  }
}

class CommandInfo {
  final int id;
  final String command;
  final String params;
  final String status;
  final DateTime? createdAt;

  CommandInfo({
    required this.id,
    required this.command,
    required this.params,
    required this.status,
    this.createdAt,
  });

  factory CommandInfo.fromJson(Map<String, dynamic> json) {
    return CommandInfo(
      id: json['id'] as int? ?? 0,
      command: json['command'] as String? ?? '',
      params: json['params']?.toString() ?? '{}',
      status: json['status'] as String? ?? 'unknown',
      createdAt: Device._parseDateTime(json['created_at']),
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return '等待中';
      case 'sent':
        return '已发送';
      case 'completed':
        return '已完成';
      case 'failed':
        return '失败';
      default:
        return status;
    }
  }

  String get commandLabel {
    switch (command) {
      case 'lock_screen':
        return '锁定屏幕';
      case 'unlock_screen':
        return '解锁屏幕';
      case 'reboot':
        return '重启设备';
      case 'enable_kiosk':
        return '启用Kiosk';
      case 'disable_kiosk':
        return '关闭Kiosk';
      case 'sync_policy':
        return '同步策略';
      default:
        return command;
    }
  }
}
