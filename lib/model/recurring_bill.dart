import 'budget.dart';
import 'category.dart';
import 'transaction.dart';

enum BillStatus { unpaid, paid }

class BillOccurrence {
  final String id;
  final DateTime dueDate;
  final double amount;
  BillStatus status;
  DateTime? paidDate;
  Transaction? paymentTransaction;

  BillOccurrence({
    required this.id,
    required this.dueDate,
    required this.amount,
    this.status = BillStatus.unpaid,
    this.paidDate,
    this.paymentTransaction,
  });

  bool get isPaid => status == BillStatus.paid;

  bool isOverdue(DateTime referenceDate) {
    return !isPaid && referenceDate.isAfter(dueDate);
  }

  void markAsPaid({
    required DateTime date,
    required Transaction transaction,
  }) {
    status = BillStatus.paid;
    paidDate = date;
    paymentTransaction = transaction;
  }
}

class RecurringBill {
  final String id;
  String name;
  double amount;
  final Category category;
  final BudgetPeriod frequency;
  final int dueDay;
  final List<BillOccurrence> occurrences;

  RecurringBill({
    required this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.frequency,
    required this.dueDay,
    List<BillOccurrence>? occurrences,
  }) : occurrences = occurrences ?? [];

  void addOccurrence(BillOccurrence occurrence) {
    occurrences.add(occurrence);
  }

  List<BillOccurrence> get unpaidOccurrences {
    return occurrences.where((o) => !o.isPaid).toList();
  }

  double get totalUnpaidAmount {
    double total = 0;
    for (final occurrence in unpaidOccurrences) {
      total += occurrence.amount;
    }
    return total;
  }
}
