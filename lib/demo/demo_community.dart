const demoGroups = {
  'badminton': 'Cầu lông phong trào',
  'morning': 'Cầu lông buổi sáng',
};

class DemoPost {
  const DemoPost({
    required this.id,
    required this.owner,
    required this.author,
    required this.groupId,
    required this.message,
    required this.created,
  });
  final String id;
  final String owner;
  final String author;
  final String groupId;
  final String message;
  final DateTime created;
  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'author': author,
    'groupId': groupId,
    'message': message,
    'created': created.toIso8601String(),
  };
  factory DemoPost.fromJson(
    Map<String, dynamic> data, {
    Set<String> additionalGroups = const {},
  }) {
    final p = DemoPost(
      id: data['id'] as String,
      owner: data['owner'] as String,
      author: data['author'] as String,
      groupId: data['groupId'] as String,
      message: data['message'] as String,
      created: DateTime.parse(data['created'] as String).toLocal(),
    );
    if (!RegExp(r'^BD\d{4,}$').hasMatch(p.id) ||
        p.author.trim().isEmpty ||
        p.author.length > 60 ||
        p.message.trim().isEmpty ||
        p.message.length > 1000 ||
        (p.groupId != 'public' &&
            !demoGroups.containsKey(p.groupId) &&
            !additionalGroups.contains(p.groupId))) {
      throw const FormatException('Invalid community post');
    }
    return p;
  }
}

class DemoExpense {
  const DemoExpense({
    required this.id,
    required this.owner,
    required this.title,
    required this.amount,
    required this.names,
    required this.created,
  });
  final String id;
  final String owner;
  final String title;
  final int amount;
  final List<String> names;
  final DateTime created;
  List<int> get shares => [
    for (var i = 0; i < names.length; i++)
      amount ~/ names.length + (i < amount % names.length ? 1 : 0),
  ];
  Map<String, Object?> toJson() => {
    'id': id,
    'owner': owner,
    'title': title,
    'amount': amount,
    'names': names,
    'created': created.toIso8601String(),
  };
  factory DemoExpense.fromJson(Map<String, dynamic> data) {
    final e = DemoExpense(
      id: data['id'] as String,
      owner: data['owner'] as String,
      title: data['title'] as String,
      amount: data['amount'] as int,
      names: List.unmodifiable((data['names'] as List).cast<String>()),
      created: DateTime.parse(data['created'] as String).toLocal(),
    );
    if (!RegExp(r'^CP\d{4,}$').hasMatch(e.id) ||
        e.title.trim().isEmpty ||
        e.title.length > 80 ||
        e.amount < 1 ||
        e.amount > 100000000 ||
        e.names.length < 2 ||
        e.names.length > 20 ||
        e.names.any((n) => n.trim().isEmpty || n.length > 60) ||
        e.names.map((n) => n.toLowerCase()).toSet().length != e.names.length) {
      throw const FormatException('Invalid expense');
    }
    return e;
  }
}
