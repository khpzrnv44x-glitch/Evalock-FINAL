class Presentation {
  final String id;
  final String description;
  final String? creatorEmail;
  final int isVisible; // 0 = Hidden, 1 = Shown
  final int areResultsVisible; // 0 = Hidden, 1 = Released

  Presentation({
    required this.id,
    required this.description,
    this.creatorEmail,
    this.isVisible = 1,
    this.areResultsVisible = 0,
  });

  factory Presentation.fromJson(Map<String, dynamic> json) {
    return Presentation(
      id: (json['id'] ?? "").toString(),
      description: json['descriptions'] ?? json['description'] ?? "",
      creatorEmail: json['creator_email'],
      // Parse visibility flags (default to Visible=1, Results=0)
      isVisible: int.tryParse(json['is_visible']?.toString() ?? "1") ?? 1,
      areResultsVisible:
          int.tryParse(json['are_results_visible']?.toString() ?? "0") ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'descriptions': description,
      'creator_email': creatorEmail,
      'is_visible': isVisible,
      'are_results_visible': areResultsVisible,
    };
  }
}

class Criteria {
  final String id;
  final String pid;
  final String description;
  final double maxMarks;
  final String commentsAllowed;

  Criteria({
    required this.id,
    required this.pid,
    required this.description,
    required this.maxMarks,
    required this.commentsAllowed,
  });

  factory Criteria.fromJson(Map<String, dynamic> json) {
    return Criteria(
      id: (json['id'] ?? "").toString(),
      pid: (json['pid'] ?? "").toString(),
      description: json['description'] ?? "",
      maxMarks: double.tryParse(json['marks']?.toString() ?? "0") ?? 0.0,
      commentsAllowed: json['comments_allowed'] ?? "No",
    );
  }
}
