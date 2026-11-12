class SpendingSummary {
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpenses;
  final double unpaidBillsTotal;
  final double? budgetLimit;
  final Map<String, double> spendingByCategory;

  SpendingSummary({
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpenses,
    required this.unpaidBillsTotal,
    required this.spendingByCategory,
    this.budgetLimit,
  });

  /// Actual balance based on recorded income and expenses.
  double get actualBalance => totalIncome - totalExpenses;

  /// Balance remaining after reserving money for unpaid bills due in the period.
  double get availableBalanceAfterBills => actualBalance - unpaidBillsTotal;

  /// Remaining budget if a budget limit was provided for this summary.
  double? get remainingBudget =>
      budgetLimit != null ? budgetLimit! - totalExpenses : null;
}
