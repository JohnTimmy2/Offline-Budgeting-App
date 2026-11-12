import 'category.dart';

enum BudgetPeriod { weekly, monthly, yearly }

class Budget {
  final String id;
  double limitAmount;
  final BudgetPeriod period;
  final DateTime startDate;
  final DateTime endDate;

  /// Optional category. If null, this budget represents an overall budget for the period.
  final Category? category;

  Budget({
    required this.id,
    required this.limitAmount,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.category,
  });

  bool get isOverallBudget => category == null;

  double calculateRemaining(double spentAmount) {
    return limitAmount - spentAmount;
  }

  bool isExceeded(double spentAmount) {
    return spentAmount > limitAmount;
  }
}
