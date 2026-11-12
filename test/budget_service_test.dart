import 'package:test/test.dart';

import '../lib/model/budget.dart';
import '../lib/model/category.dart';
import '../lib/model/recurring_bill.dart';
import '../lib/service/budget_service.dart';

void main() {
  // 1. NORMAL CASES (Valid inputs and expected successful operations)
  group('Normal Cases', () {
    test('records valid income and expense transactions and calculates summary', () {
      final service = BudgetService();
      service.addCategory(
        id: 'C1',
        name: 'Salary',
        type: TransactionType.income,
      );
      service.addCategory(
        id: 'C2',
        name: 'Food',
        type: TransactionType.expense,
      );

      service.recordTransaction(
        id: 'T1',
        title: 'Monthly Salary',
        amount: 1000.0,
        type: TransactionType.income,
        date: DateTime(2026, 11, 5),
        categoryId: 'C1',
      );
      service.recordTransaction(
        id: 'T2',
        title: 'Groceries',
        amount: 150.0,
        type: TransactionType.expense,
        date: DateTime(2026, 11, 10),
        categoryId: 'C2',
      );

      final summary = service.getSpendingSummary(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      expect(service.transactions.length, 2);
      expect(summary.totalIncome, 1000.0);
      expect(summary.totalExpenses, 150.0);
      expect(summary.actualBalance, 850.0);
      expect(summary.spendingByCategory['Food'], 150.0);
    });

    test('editing and deleting a transaction recalculates remaining budget', () {
      final service = BudgetService();
      service.addCategory(
        id: 'C1',
        name: 'Food',
        type: TransactionType.expense,
      );
      service.setBudget(
        id: 'B1',
        limitAmount: 300.0,
        period: BudgetPeriod.monthly,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        categoryId: 'C1',
      );

      service.recordTransaction(
        id: 'T1',
        title: 'Lunch',
        amount: 50.0,
        type: TransactionType.expense,
        date: DateTime(2026, 11, 12),
        categoryId: 'C1',
      );
      expect(service.calculateRemainingBudget('B1'), 250.0);

      // Edit transaction amount from 50 to 120
      service.editTransaction(transactionId: 'T1', amount: 120.0);
      expect(service.calculateRemainingBudget('B1'), 180.0);

      // Delete transaction
      service.deleteTransaction('T1');
      expect(service.calculateRemainingBudget('B1'), 300.0);
    });

    test('distinguishes actual balance from unpaid bills and marks bill as paid', () {
      final service = BudgetService();
      service.addCategory(
        id: 'C_INC',
        name: 'Salary',
        type: TransactionType.income,
      );
      service.addCategory(
        id: 'C_BILLS',
        name: 'Utilities',
        type: TransactionType.expense,
      );

      service.recordTransaction(
        id: 'T1',
        title: 'Salary',
        amount: 800.0,
        type: TransactionType.income,
        date: DateTime(2026, 11, 1),
        categoryId: 'C_INC',
      );

      service.addRecurringBill(
        id: 'RB1',
        name: 'Electricity',
        amount: 60.0,
        categoryId: 'C_BILLS',
        frequency: BudgetPeriod.monthly,
        dueDay: 15,
      );
      service.scheduleBillOccurrence(
        billId: 'RB1',
        occurrenceId: 'OCC1',
        dueDate: DateTime(2026, 11, 15),
      );

      // Before paying bill: actual balance is 800, reserved for unpaid bill is 60
      final beforePayment = service.getSpendingSummary(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );
      expect(beforePayment.actualBalance, 800.0);
      expect(beforePayment.unpaidBillsTotal, 60.0);
      expect(beforePayment.availableBalanceAfterBills, 740.0);

      // Mark bill as paid
      final paymentTx = service.markBillAsPaid(
        billId: 'RB1',
        occurrenceId: 'OCC1',
        transactionId: 'T2',
        paidDate: DateTime(2026, 11, 14),
      );

      expect(paymentTx.amount, 60.0);
      expect(
        service.recurringBills.first.occurrences.first.status,
        BillStatus.paid,
      );

      // After paying bill: actual balance is now 740, unpaid bills total is 0
      final afterPayment = service.getSpendingSummary(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );
      expect(afterPayment.actualBalance, 740.0);
      expect(afterPayment.unpaidBillsTotal, 0.0);
      expect(afterPayment.availableBalanceAfterBills, 740.0);
    });
  });
  // 2. INVALID CASES (Invalid inputs or operations violating business rules)
  group('Invalid Cases', () {
    test('cannot record a transaction with zero or negative amount', () {
      final service = BudgetService();
      service.addCategory(
        id: 'C1',
        name: 'Food',
        type: TransactionType.expense,
      );

      expect(
        () => service.recordTransaction(
          id: 'T1',
          title: 'Invalid Zero Expense',
          amount: 0.0,
          type: TransactionType.expense,
          date: DateTime(2026, 11, 10),
          categoryId: 'C1',
        ),
        throwsException,
      );

      expect(
        () => service.recordTransaction(
          id: 'T2',
          title: 'Invalid Negative Expense',
          amount: -25.0,
          type: TransactionType.expense,
          date: DateTime(2026, 11, 10),
          categoryId: 'C1',
        ),
        throwsException,
      );
    });

    test('cannot record a transaction with non-existing or mismatched category', () {
      final service = BudgetService();
      service.addCategory(
        id: 'C_INC',
        name: 'Salary',
        type: TransactionType.income,
      );

      // Non-existing category
      expect(
        () => service.recordTransaction(
          id: 'T1',
          title: 'Coffee',
          amount: 5.0,
          type: TransactionType.expense,
          date: DateTime(2026, 11, 10),
          categoryId: 'NON_EXISTING',
        ),
        throwsException,
      );

      // Expense transaction using an Income category
      expect(
        () => service.recordTransaction(
          id: 'T2',
          title: 'Coffee',
          amount: 5.0,
          type: TransactionType.expense,
          date: DateTime(2026, 11, 10),
          categoryId: 'C_INC',
        ),
        throwsException,
      );
    });

    test('cannot mark an already paid bill occurrence as paid twice', () {
      final service = BudgetService();
      service.addCategory(
        id: 'C1',
        name: 'Rent',
        type: TransactionType.expense,
      );
      service.addRecurringBill(
        id: 'RB1',
        name: 'Apartment Rent',
        amount: 250.0,
        categoryId: 'C1',
        frequency: BudgetPeriod.monthly,
        dueDay: 1,
      );
      service.scheduleBillOccurrence(
        billId: 'RB1',
        occurrenceId: 'OCC1',
        dueDate: DateTime(2026, 11, 1),
      );

      service.markBillAsPaid(
        billId: 'RB1',
        occurrenceId: 'OCC1',
        transactionId: 'T1',
        paidDate: DateTime(2026, 11, 1),
      );

      expect(
        () => service.markBillAsPaid(
          billId: 'RB1',
          occurrenceId: 'OCC1',
          transactionId: 'T2',
          paidDate: DateTime(2026, 11, 2),
        ),
        throwsException,
      );
    });

    test('cannot create overlapping budgets for the same period and category', () {
      final service = BudgetService();
      service.addCategory(
        id: 'C1',
        name: 'Food',
        type: TransactionType.expense,
      );

      service.setBudget(
        id: 'B1',
        limitAmount: 200.0,
        period: BudgetPeriod.monthly,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        categoryId: 'C1',
      );

      expect(
        () => service.setBudget(
          id: 'B2',
          limitAmount: 250.0,
          period: BudgetPeriod.monthly,
          startDate: DateTime(2026, 11, 15),
          endDate: DateTime(2026, 12, 15),
          categoryId: 'C1',
        ),
        throwsException,
      );
    });
  });

  // 3. BOUNDARY OR SPECIAL CASES (Edge conditions that may affect the result)
  group('Boundary and Special Cases', () {
    test('returns zero spending when there are no transactions in the period', () {
      final service = BudgetService();
      service.setBudget(
        id: 'B1',
        limitAmount: 500.0,
        period: BudgetPeriod.monthly,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
      );

      final summary = service.getSpendingSummary(
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        budgetId: 'B1',
      );

      expect(summary.totalIncome, 0.0);
      expect(summary.totalExpenses, 0.0);
      expect(summary.actualBalance, 0.0);
      expect(summary.remainingBudget, 500.0);
      expect(summary.spendingByCategory, isEmpty);
    });

    test('includes transactions occurring on exact start and end boundary dates of budget', () {
      final service = BudgetService();
      service.addCategory(
        id: 'C1',
        name: 'Transport',
        type: TransactionType.expense,
      );

      final start = DateTime(2026, 11, 1);
      final end = DateTime(2026, 11, 30);

      service.setBudget(
        id: 'B1',
        limitAmount: 100.0,
        period: BudgetPeriod.monthly,
        startDate: start,
        endDate: end,
        categoryId: 'C1',
      );

      // Transaction on exact start boundary
      service.recordTransaction(
        id: 'T1',
        title: 'Bus Pass Start',
        amount: 20.0,
        type: TransactionType.expense,
        date: start,
        categoryId: 'C1',
      );

      // Transaction on exact end boundary
      service.recordTransaction(
        id: 'T2',
        title: 'Taxi End',
        amount: 30.0,
        type: TransactionType.expense,
        date: end,
        categoryId: 'C1',
      );

      // Transaction 1 day after end boundary (should be excluded)
      service.recordTransaction(
        id: 'T3',
        title: 'Next Month Fuel',
        amount: 40.0,
        type: TransactionType.expense,
        date: DateTime(2026, 12, 1),
        categoryId: 'C1',
      );

      expect(service.calculateRemainingBudget('B1'), 50.0);
    });

    test('spending exactly equal to budget limit results in zero remaining budget without exceeding', () {
      final service = BudgetService();
      service.addCategory(
        id: 'C1',
        name: 'Internet',
        type: TransactionType.expense,
      );

      final budget = service.setBudget(
        id: 'B1',
        limitAmount: 100.0,
        period: BudgetPeriod.monthly,
        startDate: DateTime(2026, 11, 1),
        endDate: DateTime(2026, 11, 30),
        categoryId: 'C1',
      );

      service.recordTransaction(
        id: 'T1',
        title: 'Fiber Plan',
        amount: 100.0,
        type: TransactionType.expense,
        date: DateTime(2026, 11, 10),
        categoryId: 'C1',
      );

      expect(service.calculateRemainingBudget('B1'), 0.0);
      expect(budget.isExceeded(100.0), isFalse);
      expect(budget.isExceeded(100.01), isTrue);
    });
  });
}
