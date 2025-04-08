// lib/models/performance_metrics_model.dart

class PerformanceMetrics {
  final int id;
  final int deviceId;
  final double cpuUsage;
  final double memoryUsage;
  final double temperature;
  final int pingMs;
  final double throughputMbps;
  final int activeConnections;
  final DateTime collectedAt;
  final UbntSpecificData? ubntSpecificData;
  final MikrotikSpecificData? mikrotikSpecificData;

  PerformanceMetrics({
    this.id = 0,
    required this.deviceId,
    required this.cpuUsage,
    required this.memoryUsage,
    required this.temperature,
    required this.pingMs,
    required this.throughputMbps,
    required this.activeConnections,
    required this.collectedAt,
    this.ubntSpecificData,
    this.mikrotikSpecificData,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return PerformanceMetrics(
      id: json['id'] ?? 0,
      deviceId: json['device_id'],
      cpuUsage: json['cpu_usage'].toDouble(),
      memoryUsage: json['memory_usage'].toDouble(),
      temperature: json['temperature'].toDouble(),
      pingMs: json['ping_ms'],
      throughputMbps: json['throughput_mbps'].toDouble(),
      activeConnections: json['active_connections'],
      collectedAt: DateTime.parse(json['collected_at']),
      ubntSpecificData: json['ubnt_data'] != null
          ? UbntSpecificData.fromJson(json['ubnt_data'])
          : null,
      mikrotikSpecificData: json['mikrotik_data'] != null
          ? MikrotikSpecificData.fromJson(json['mikrotik_data'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final map = {
      'id': id,
      'device_id': deviceId,
      'cpu_usage': cpuUsage,
      'memory_usage': memoryUsage,
      'temperature': temperature,
      'ping_ms': pingMs,
      'throughput_mbps': throughputMbps,
      'active_connections': activeConnections,
      'collected_at': collectedAt.toIso8601String(),
    };

    if (ubntSpecificData != null) {
      map['ubnt_data'] = ubntSpecificData!.toJson();
    }

    if (mikrotikSpecificData != null) {
      map['mikrotik_data'] = mikrotikSpecificData!.toJson();
    }

    return map;
  }
}

class UbntSpecificData {
  final int id;
  final int deviceId;
  final double signalStrength;
  final double airtimeUtilization;
  final int connectedClients;
  final DateTime collectedAt;

  UbntSpecificData({
    this.id = 0,
    required this.deviceId,
    required this.signalStrength,
    required this.airtimeUtilization,
    required this.connectedClients,
    required this.collectedAt,
  });

  factory UbntSpecificData.fromJson(Map<String, dynamic> json) {
    return UbntSpecificData(
      id: json['id'] ?? 0,
      deviceId: json['device_id'],
      signalStrength: json['signal_strength'].toDouble(),
      airtimeUtilization: json['airtime_utilization'].toDouble(),
      connectedClients: json['connected_clients'],
      collectedAt: DateTime.parse(json['collected_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'signal_strength': signalStrength,
      'airtime_utilization': airtimeUtilization,
      'connected_clients': connectedClients,
      'collected_at': collectedAt.toIso8601String(),
    };
  }
}

class MikrotikSpecificData {
  final int id;
  final int deviceId;
  final int activeFirewallRules;
  final int vpnConnections;
  final double queueUtilization;
  final DateTime collectedAt;

  MikrotikSpecificData({
    this.id = 0,
    required this.deviceId,
    required this.activeFirewallRules,
    required this.vpnConnections,
    required this.queueUtilization,
    required this.collectedAt,
  });

  factory MikrotikSpecificData.fromJson(Map<String, dynamic> json) {
    return MikrotikSpecificData(
      id: json['id'] ?? 0,
      deviceId: json['device_id'],
      activeFirewallRules: json['active_firewall_rules'],
      vpnConnections: json['vpn_connections'],
      queueUtilization: json['queue_utilization'].toDouble(),
      collectedAt: DateTime.parse(json['collected_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'active_firewall_rules': activeFirewallRules,
      'vpn_connections': vpnConnections,
      'queue_utilization': queueUtilization,
      'collected_at': collectedAt.toIso8601String(),
    };
  }
}

class Alert {
  final int id;
  final int deviceId;
  final String type;
  final String message;
  final bool isResolved;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  Alert({
    this.id = 0,
    required this.deviceId,
    required this.type,
    required this.message,
    required this.isResolved,
    required this.createdAt,
    this.resolvedAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['id'] ?? 0,
      deviceId: json['device_id'],
      type: json['type'],
      message: json['message'],
      isResolved: json['is_resolved'] == 1,
      createdAt: DateTime.parse(json['created_at']),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'type': type,
      'message': message,
      'is_resolved': isResolved ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }
}