class AdminStatsModel {
  final int totalUsers;
  final int activeUsers;
  final int totalLectures;
  final double totalDurationMinutes;
  final double totalStorageMb;
  final int totalLogs;
  final int errorLogs;
  final List<Map<String, dynamic>> statusBreakdown;
  final List<Map<String, dynamic>> recentActivity;

  AdminStatsModel({
    this.totalUsers = 0,
    this.activeUsers = 0,
    this.totalLectures = 0,
    this.totalDurationMinutes = 0.0,
    this.totalStorageMb = 0.0,
    this.totalLogs = 0,
    this.errorLogs = 0,
    this.statusBreakdown = const [],
    this.recentActivity = const [],
  });

  factory AdminStatsModel.fromJson(Map<String, dynamic> json) {
    return AdminStatsModel(
      totalUsers: json['total_users'] ?? 0,
      activeUsers: json['active_users'] ?? 0,
      totalLectures: json['total_lectures'] ?? 0,
      totalDurationMinutes: (json['total_duration_minutes'] as num?)?.toDouble() ?? 0.0,
      totalStorageMb: (json['total_storage_mb'] as num?)?.toDouble() ?? 0.0,
      totalLogs: json['total_logs'] ?? 0,
      errorLogs: json['error_logs'] ?? 0,
      statusBreakdown: (json['status_breakdown'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [],
      recentActivity: (json['recent_activity'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? [],
    );
  }
}
