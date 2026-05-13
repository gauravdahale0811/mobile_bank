import 'loan.dart';
import 'emi_payment.dart';

/// Combines a Loan and one of its pending EmiPayments for the
/// Today's Collection screen.
class DuePayment {
  final Loan loan;
  final EmiPayment payment;

  const DuePayment({required this.loan, required this.payment});

  /// Fine applies when the due date has already passed.
  bool get hasLateFine => payment.isOverdue;

  double get fineIfPaidNow => hasLateFine ? lateFineAmount : 0;

  double get totalIfPaidNow => payment.amount + fineIfPaidNow;
}
