class User {
  final String id;
  final String name;
  final String email;
  final String rollNo;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.rollNo,
  });

  // From API JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['user_id']?.toString() ?? json['id']?.toString() ?? "0",
      name:
          json['user_full_name'] ??
          json['full_name'] ??
          json['name'] ??
          "Unknown",
      email: json['user_email'] ?? json['email'] ?? "",
      rollNo: json['rollno']?.toString() ?? "",
    );
  }

  // --- NEW: Convert to Map for Local Database ---
  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'email': email, 'roll_no': rollNo};
  }

  // --- NEW: Create from Local Database ---
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      rollNo: map['roll_no'],
    );
  }
}
