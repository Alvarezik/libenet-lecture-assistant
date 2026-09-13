class LogModel {
  final int id;
  final int? userId;
  final String username;
  final String action;
  final String category;
  final String level; // 'INFO', 'WARN', 'ERROR'
  final String details;
  final String ipAddress;
  final String createdAt;

  String get formattedTime {
    if (createdAt.isEmpty) return '';
    try {
      final dt = DateTime.parse(createdAt);
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      final s = dt.second.toString().padLeft(2, '0');
      return '$h:$m:$s';
    } catch (_) {
      return createdAt;
    }
  }

  LogModel({
    required this.id,
    this.userId,
    required this.username,
    required this.action,
    required this.category,
    required this.level,
    required this.details,
    required this.ipAddress,
    required this.createdAt,
  });

  factory LogModel.fromJson(Map<String, dynamic> json) {
    return LogModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      userId: json['user_id'] is int ? json['user_id'] : int.tryParse(json['user_id']?.toString() ?? ''),
      username: json['username'] ?? 'Anonymous',
      action: json['action'] ?? '',
      category: json['category'] ?? 'general',
      level: (json['level'] ?? 'INFO').toUpperCase(),
      details: json['details'] ?? '',
      ipAddress: json['ip_address'] ?? '',
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}
