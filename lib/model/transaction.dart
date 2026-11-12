import 'category.dart';

class Transaction {
  final String id;
  String title;
  double amount;
  final TransactionType type;
  DateTime date;
  Category category;
  String? note;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.date,
    required this.category,
    this.note,
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  /// Checks whether this transaction occurred within [startDate] and [endDate] (inclusive).
  bool isWithinPeriod(DateTime startDate, DateTime endDate) {
    return !date.isBefore(startDate) && !date.isAfter(endDate);
  }
}
