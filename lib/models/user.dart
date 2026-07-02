class AppUser {
  final int? id;
  final String username;
  final String passwordHash;

  AppUser({this.id, required this.username, required this.passwordHash});

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'passwordHash': passwordHash,
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as int?,
        username: map['username'] as String,
        passwordHash: map['passwordHash'] as String,
      );
}
