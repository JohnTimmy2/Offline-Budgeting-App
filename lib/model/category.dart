enum TransactionType { income, expense }

class Category {
  final String id;
  String name;
  final TransactionType type;

  Category({
    required this.id,
    required this.name,
    required this.type,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;
}
