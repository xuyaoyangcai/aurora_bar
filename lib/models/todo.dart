class Todo {
  final String id;
  final String title;
  bool completed;
  final DateTime createdAt;
  DateTime? dueDate;
  String? category; // 'personal', 'work', 'urgent'

  Todo({
    required this.id,
    required this.title,
    this.completed = false,
    DateTime? createdAt,
    this.dueDate,
    this.category,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
        'dueDate': dueDate?.toIso8601String(),
        'category': category,
      };

  factory Todo.fromJson(Map<String, dynamic> json) => Todo(
        id: json['id'] as String,
        title: json['title'] as String,
        completed: json['completed'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        category: json['category'] as String?,
      );
}
