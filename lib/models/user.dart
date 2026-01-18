class UserModel {
  final String name;
  final String email;
  final String loginType;
  final int savedNewsCount;
  final int savedEventsCount;

  UserModel({
    required this.name,
    required this.email,
    required this.loginType,
    required this.savedNewsCount,
    required this.savedEventsCount,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'],
      email: json['email'],
      loginType: json['loginType'],
      savedNewsCount: json['saved_news'].length,
      savedEventsCount: json['saved_events'].length,
    );
  }
}
