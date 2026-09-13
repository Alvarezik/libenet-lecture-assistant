class UserModel {
  final int id;
  final String username;
  final String email;
  final String role;
  final String fullName;
  final bool isActive;
  final String? createdAt;
  final String? lastLogin;
  final int lecturesCount;
  final bool canTranscribe;
  final bool canSummarize;
  final bool canChatGeneral;
  final bool canChatLecture;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.fullName = '',
    this.isActive = true,
    this.createdAt,
    this.lastLogin,
    this.lecturesCount = 0,
    this.canTranscribe = true,
    this.canSummarize = true,
    this.canChatGeneral = true,
    this.canChatLecture = true,
  });

  bool get isAdmin => role == 'admin';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? 'user',
      fullName: json['full_name'] ?? '',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: json['created_at']?.toString(),
      lastLogin: json['last_login']?.toString(),
      lecturesCount: json['lectures_count'] is int ? json['lectures_count'] : int.tryParse(json['lectures_count']?.toString() ?? '0') ?? 0,
      canTranscribe: json['can_transcribe'] == null ? true : (json['can_transcribe'] == 1 || json['can_transcribe'] == true),
      canSummarize: json['can_summarize'] == null ? true : (json['can_summarize'] == 1 || json['can_summarize'] == true),
      canChatGeneral: json['can_chat_general'] == null ? true : (json['can_chat_general'] == 1 || json['can_chat_general'] == true),
      canChatLecture: json['can_chat_lecture'] == null ? true : (json['can_chat_lecture'] == 1 || json['can_chat_lecture'] == true),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role,
      'full_name': fullName,
      'is_active': isActive,
      'created_at': createdAt,
      'last_login': lastLogin,
      'can_transcribe': canTranscribe,
      'can_summarize': canSummarize,
      'can_chat_general': canChatGeneral,
      'can_chat_lecture': canChatLecture,
    };
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? email,
    String? role,
    String? fullName,
    bool? isActive,
    String? createdAt,
    String? lastLogin,
    int? lecturesCount,
    bool? canTranscribe,
    bool? canSummarize,
    bool? canChatGeneral,
    bool? canChatLecture,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      lecturesCount: lecturesCount ?? this.lecturesCount,
      canTranscribe: canTranscribe ?? this.canTranscribe,
      canSummarize: canSummarize ?? this.canSummarize,
      canChatGeneral: canChatGeneral ?? this.canChatGeneral,
      canChatLecture: canChatLecture ?? this.canChatLecture,
    );
  }
}
