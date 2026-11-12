import '../model/budget.dart';
import '../model/category.dart';
import '../model/recurring_bill.dart';
import '../model/spending_summary.dart';
import '../model/transaction.dart';

class BudgetService {
  final List<Category> categories = [];
  final List<Transaction> transactions = [];
  final List<Budget> budgets = [];
  final List<RecurringBill> recurringBills = [];

  // ---------------------------------------------------------------------------
  // 1. Category Management
  // ---------------------------------------------------------------------------

  Category addCategory({
    required String id,
    required String name,
    required TransactionType type,
  }) {
    // ! Category ID shall not exist already
    if (_findCategoryOrNull(id) != null) {
      throw Exception('Category $id already exists');
    }

    // ! Category name shall not be empty
    if (name.trim().isEmpty) {
      throw Exception('Category name cannot be empty');
    }

    final category = Category(id: id, name: name.trim(), type: type);
    categories.add(category);
    return category;
  }

  // ---------------------------------------------------------------------------
  // 2. Transaction Operations (Income & Expenses)
  // ---------------------------------------------------------------------------

  Transaction recordTransaction({
    required String id,
    required String title,
    required double amount,
    required TransactionType type,
    required DateTime date,
    required String categoryId,
    String? note,
  }) {
    // ! Transaction ID shall not exist already
    if (_findTransactionOrNull(id) != null) {
      throw Exception('Transaction $id already exists');
    }

    // ! Title shall not be empty
    if (title.trim().isEmpty) {
      throw Exception('Transaction title cannot be empty');
    }

    // ! Amount shall be strictly positive (> 0)
    if (amount <= 0) {
      throw Exception('Transaction amount must be greater than zero');
    }

    // ! Category shall exist
    final category = _findCategoryOrNull(categoryId);
    if (category == null) {
      throw Exception('Category $categoryId not found');
    }

    // ! Category type shall match transaction type
    if (category.type != type) {
      throw Exception(
        'Category ${category.name} (${category.type.name}) does not match transaction type (${type.name})',
      );
    }

    final transaction = Transaction(
      id: id,
      title: title.trim(),
      amount: amount,
      type: type,
      date: date,
      category: category,
      note: note,
    );
    transactions.add(transaction);
    return transaction;
  }

  void editTransaction({
    required String transactionId,
    String? title,
    double? amount,
    DateTime? date,
    String? categoryId,
    String? note,
  }) {
    // ! Transaction shall exist
    final transaction = _findTransactionOrNull(transactionId);
    if (transaction == null) {
      throw Exception('Transaction $transactionId not found');
    }

    // ! New title (if provided) shall not be empty
    if (title != null && title.trim().isEmpty) {
      throw Exception('Transaction title cannot be empty');
    }

    // ! New amount (if provided) shall be strictly positive (> 0)
    if (amount != null && amount <= 0) {
      throw Exception('Transaction amount must be greater than zero');
    }

    // ! New category (if provided) shall exist and match transaction type
    Category? updatedCategory;
    if (categoryId != null) {
      updatedCategory = _findCategoryOrNull(categoryId);
      if (updatedCategory == null) {
        throw Exception('Category $categoryId not found');
      }
      if (updatedCategory.type != transaction.type) {
        throw Exception(
          'Category ${updatedCategory.name} does not match transaction type (${transaction.type.name})',
        );
      }
    }

    if (title != null) transaction.title = title.trim();
    if (amount != null) transaction.amount = amount;
    if (date != null) transaction.date = date;
    if (updatedCategory != null) transaction.category = updatedCategory;
    if (note != null) transaction.note = note;
  }

  void deleteTransaction(String transactionId) {
    // ! Transaction shall exist
    final transaction = _findTransactionOrNull(transactionId);
    if (transaction == null) {
      throw Exception('Transaction $transactionId not found');
    }

    transactions.remove(transaction);
  }

  // ---------------------------------------------------------------------------
  // 3. Budget Operations
  // ---------------------------------------------------------------------------

  Budget setBudget({
    required String id,
    required double limitAmount,
    required BudgetPeriod period,
    required DateTime startDate,
    required DateTime endDate,
    String? categoryId,
  }) {
    // ! Budget ID shall not exist already
    if (_findBudgetOrNull(id) != null) {
      throw Exception('Budget $id already exists');
    }

    // ! Budget limit shall be strictly positive (> 0)
    if (limitAmount <= 0) {
      throw Exception('Budget limit amount must be greater than zero');
    }

    // ! Start date shall not be after end date
    if (endDate.isBefore(startDate)) {
      throw Exception('Budget end date cannot be before start date');
    }

    // ! If categoryId is specified, category shall exist and be an expense category
    Category? category;
    if (categoryId != null) {
      category = _findCategoryOrNull(categoryId);
      if (category == null) {
        throw Exception('Category $categoryId not found');
      }
      if (!category.isExpense) {
        throw Exception('Budgets can only be set for expense categories');
      }
    }

    // ! Cannot create an overlapping budget for the same period and category scope
    if (_hasOverlappingBudget(period, startDate, endDate, categoryId)) {
      throw Exception(
        'An overlapping budget already exists for this period and category',
      );
    }

    final budget = Budget(
      id: id,
      limitAmount: limitAmount,
      period: period,
      startDate: startDate,
      endDate: endDate,
      category: category,
    );
    budgets.add(budget);
    return budget;
  }

  double calculateRemainingBudget(String budgetId) {
    // ! Budget shall exist
    final budget = _findBudgetOrNull(budgetId);
    if (budget == null) {
      throw Exception('Budget $budgetId not found');
    }

    double spent = 0;
    for (final tx in transactions) {
      if (tx.isExpense && tx.isWithinPeriod(budget.startDate, budget.endDate)) {
        if (budget.isOverallBudget || tx.category.id == budget.category!.id) {
          spent += tx.amount;
        }
      }
    }

    return budget.calculateRemaining(spent);
  }

  // ---------------------------------------------------------------------------
  // 4. Recurring Bills & Bill Payments
  // ---------------------------------------------------------------------------

  RecurringBill addRecurringBill({
    required String id,
    required String name,
    required double amount,
    required String categoryId,
    required BudgetPeriod frequency,
    required int dueDay,
  }) {
    // ! Recurring bill ID shall not exist already
    if (_findRecurringBillOrNull(id) != null) {
      throw Exception('Recurring bill $id already exists');
    }

    // ! Bill name shall not be empty
    if (name.trim().isEmpty) {
      throw Exception('Recurring bill name cannot be empty');
    }

    // ! Bill amount shall be strictly positive (> 0)
    if (amount <= 0) {
      throw Exception('Recurring bill amount must be greater than zero');
    }

    // ! Due day shall be between 1 and 31
    if (dueDay < 1 || dueDay > 31) {
      throw Exception('Due day must be between 1 and 31');
    }

    // ! Category shall exist and be an expense category
    final category = _findCategoryOrNull(categoryId);
    if (category == null) {
      throw Exception('Category $categoryId not found');
    }
    if (!category.isExpense) {
      throw Exception('Recurring bill category must be an expense category');
    }

    final bill = RecurringBill(
      id: id,
      name: name.trim(),
      amount: amount,
      category: category,
      frequency: frequency,
      dueDay: dueDay,
    );
    recurringBills.add(bill);
    return bill;
  }

  BillOccurrence scheduleBillOccurrence({
    required String billId,
    required String occurrenceId,
    required DateTime dueDate,
    double? customAmount,
  }) {
    // ! Recurring bill shall exist
    final bill = _findRecurringBillOrNull(billId);
    if (bill == null) {
      throw Exception('Recurring bill $billId not found');
    }

    // ! Occurrence ID shall not exist already on this bill
    if (_findOccurrenceOrNull(bill, occurrenceId) != null) {
      throw Exception('Bill occurrence $occurrenceId already exists');
    }

    // ! Custom amount (if provided) shall be strictly positive (> 0)
    if (customAmount != null && customAmount <= 0) {
      throw Exception('Bill occurrence amount must be greater than zero');
    }

    final occurrence = BillOccurrence(
      id: occurrenceId,
      dueDate: dueDate,
      amount: customAmount ?? bill.amount,
    );
    bill.addOccurrence(occurrence);
    return occurrence;
  }

  Transaction markBillAsPaid({
    required String billId,
    required String occurrenceId,
    required String transactionId,
    required DateTime paidDate,
  }) {
    // ! Recurring bill shall exist
    final bill = _findRecurringBillOrNull(billId);
    if (bill == null) {
      throw Exception('Recurring bill $billId not found');
    }

    // ! Bill occurrence shall exist
    final occurrence = _findOccurrenceOrNull(bill, occurrenceId);
    if (occurrence == null) {
      throw Exception('Bill occurrence $occurrenceId not found');
    }

    // ! Bill occurrence shall not already be paid
    if (occurrence.isPaid) {
      throw Exception('Bill occurrence $occurrenceId is already marked as paid');
    }

    // ! Transaction ID shall not exist already
    if (_findTransactionOrNull(transactionId) != null) {
      throw Exception('Transaction $transactionId already exists');
    }

    final paymentTransaction = recordTransaction(
      id: transactionId,
      title: '${bill.name} Payment',
      amount: occurrence.amount,
      type: TransactionType.expense,
      date: paidDate,
      categoryId: bill.category.id,
    );

    occurrence.markAsPaid(
      date: paidDate,
      transaction: paymentTransaction,
    );

    return paymentTransaction;
  }

  // ---------------------------------------------------------------------------
  // 5. Spending Summaries & Upcoming Bills
  // ---------------------------------------------------------------------------

  SpendingSummary getSpendingSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? budgetId,
  }) {
    // ! Start date shall not be after end date
    if (endDate.isBefore(startDate)) {
      throw Exception('Summary end date cannot be before start date');
    }

    // ! If budgetId is provided, budget shall exist
    Budget? budget;
    if (budgetId != null) {
      budget = _findBudgetOrNull(budgetId);
      if (budget == null) {
        throw Exception('Budget $budgetId not found');
      }
    }

    double totalIncome = 0;
    double totalExpenses = 0;
    final Map<String, double> spendingByCategory = {};

    for (final tx in transactions) {
      if (tx.isWithinPeriod(startDate, endDate)) {
        if (tx.isIncome) {
          totalIncome += tx.amount;
        } else {
          totalExpenses += tx.amount;
          spendingByCategory[tx.category.name] =
              (spendingByCategory[tx.category.name] ?? 0) + tx.amount;
        }
      }
    }

    double unpaidBillsTotal = 0;
    for (final bill in recurringBills) {
      for (final occurrence in bill.unpaidOccurrences) {
        if (!occurrence.dueDate.isBefore(startDate) &&
            !occurrence.dueDate.isAfter(endDate)) {
          unpaidBillsTotal += occurrence.amount;
        }
      }
    }

    return SpendingSummary(
      startDate: startDate,
      endDate: endDate,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      unpaidBillsTotal: unpaidBillsTotal,
      spendingByCategory: spendingByCategory,
      budgetLimit: budget?.limitAmount,
    );
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  Category? _findCategoryOrNull(String categoryId) {
    for (final c in categories) {
      if (c.id == categoryId) return c;
    }
    return null;
  }

  Transaction? _findTransactionOrNull(String transactionId) {
    for (final t in transactions) {
      if (t.id == transactionId) return t;
    }
    return null;
  }

  Budget? _findBudgetOrNull(String budgetId) {
    for (final b in budgets) {
      if (b.id == budgetId) return b;
    }
    return null;
  }

  RecurringBill? _findRecurringBillOrNull(String billId) {
    for (final b in recurringBills) {
      if (b.id == billId) return b;
    }
    return null;
  }

  BillOccurrence? _findOccurrenceOrNull(
    RecurringBill bill,
    String occurrenceId,
  ) {
    for (final o in bill.occurrences) {
      if (o.id == occurrenceId) return o;
    }
    return null;
  }

  bool _hasOverlappingBudget(
    BudgetPeriod period,
    DateTime startDate,
    DateTime endDate,
    String? categoryId,
  ) {
    for (final b in budgets) {
      final sameCategory = b.category?.id == categoryId;
      final datesOverlap =
          !startDate.isAfter(b.endDate) && !endDate.isBefore(b.startDate);
      if (b.period == period && sameCategory && datesOverlap) {
        return true;
      }
    }
    return false;
  }
}
