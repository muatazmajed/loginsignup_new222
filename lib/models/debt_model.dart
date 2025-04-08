class DebtModel {
  final int? id;
  final int? userId;
  final String username;
  final String? phoneNumber;
  final double amount;
  final DateTime dueDate;
  final DateTime createdAt;
  final bool isPaid;
  final String? notes;

  DebtModel({
    this.id,
    this.userId,
    required this.username,
    this.phoneNumber,
    required this.amount,
    required this.dueDate,
    required this.createdAt,
    required this.isPaid,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'phoneNumber': phoneNumber,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'isPaid': isPaid ? 1 : 0,
      'notes': notes,
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'] as int?,
      userId: map['userId'] as int?,
      username: map['username'] as String,
      phoneNumber: map['phoneNumber'] as String?,
      amount: map['amount'] as double,
      dueDate: DateTime.parse(map['dueDate'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      isPaid: (map['isPaid'] as int) == 1,
      notes: map['notes'] as String?,
    );
  }

  // إضافة طريقة لعمل نسخة من الكائن مع تغيير بعض القيم
  DebtModel copyWith({
    int? id,
    int? userId,
    String? username,
    String? phoneNumber,
    double? amount,
    DateTime? dueDate,
    DateTime? createdAt,
    bool? isPaid,
    String? notes,
  }) {
    return DebtModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      isPaid: isPaid ?? this.isPaid,
      notes: notes ?? this.notes,
    );
  }
}