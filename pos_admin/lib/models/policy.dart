class Policy {
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    final dt = DateTime.tryParse(value.toString());
    return dt?.toLocal();
  }

  final int id;
  final String policyName;
  final Map<String, dynamic> policyData;
  final int version;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Policy({
    required this.id,
    required this.policyName,
    required this.policyData,
    required this.version,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: json['id'] as int? ?? 0,
      policyName: json['policy_name'] as String? ?? '',
      policyData: (json['policy_data'] is Map)
          ? Map<String, dynamic>.from(json['policy_data'])
          : {},
      version: json['version'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  String get statusLabel => isActive ? '启用' : '停用';
}

class PolicyDetail {
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    final dt = DateTime.tryParse(value.toString());
    return dt?.toLocal();
  }

  final int id;
  final String policyName;
  final Map<String, dynamic> policyData;
  final int version;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<BoundDevice> boundDevices;

  PolicyDetail({
    required this.id,
    required this.policyName,
    required this.policyData,
    required this.version,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.boundDevices = const [],
  });

  factory PolicyDetail.fromJson(Map<String, dynamic> json) {
    return PolicyDetail(
      id: json['id'] as int? ?? 0,
      policyName: json['policy_name'] as String? ?? '',
      policyData: (json['policy_data'] is Map)
          ? Map<String, dynamic>.from(json['policy_data'])
          : {},
      version: json['version'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
      boundDevices: (json['bound_devices'] as List?)
              ?.map((e) => BoundDevice.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BoundDevice {
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    final dt = DateTime.tryParse(value.toString());
    return dt?.toLocal();
  }

  final String deviceId;
  final String? deviceStatus;
  final String bindStatus;
  final DateTime? syncedAt;

  BoundDevice({
    required this.deviceId,
    this.deviceStatus,
    required this.bindStatus,
    this.syncedAt,
  });

  factory BoundDevice.fromJson(Map<String, dynamic> json) {
    return BoundDevice(
      deviceId: json['device_id'] as String? ?? '',
      deviceStatus: json['device_status'] as String?,
      bindStatus: json['bind_status'] as String? ?? 'pending',
      syncedAt: _parseDateTime(json['synced_at']),
    );
  }

  String get bindStatusLabel {
    switch (bindStatus) {
      case 'pending':
        return '待同步';
      case 'synced':
        return '已同步';
      default:
        return bindStatus;
    }
  }
}
