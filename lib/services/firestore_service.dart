import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/loan.dart';
import '../models/emi_payment.dart';
import '../models/due_payment.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // All data lives under /users/{lenderUid}/... — each lender's
  // records are completely isolated from every other lender.
  String get _uid => _auth.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _loans =>
      _db.collection('users').doc(_uid).collection('loans');

  CollectionReference<Map<String, dynamic>> _payments(String loanId) =>
      _loans.doc(loanId).collection('payments');

  // ── Loans ──────────────────────────────────────────────────────────────────

  Stream<List<Loan>> loansStream() {
    return _loans
        .orderBy('disbursementDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Loan.fromFirestore).toList());
  }

  Future<Loan> addLoan(Loan loan) async {
    final ref = await _loans.add(loan.toFirestore());
    final doc = await ref.get();
    final savedLoan = Loan.fromFirestore(doc);
    await _generateEmiSchedule(savedLoan);
    return savedLoan;
  }

  /// Update only borrower details — financial terms are immutable after creation.
  Future<void> updateLoanDetails(
    String loanId, {
    required String borrowerName,
    required String borrowerPhone,
    String? notes,
  }) async {
    await _loans.doc(loanId).update({
      'borrowerName': borrowerName,
      'borrowerPhone': borrowerPhone,
      'notes': notes,
    });
  }

  Future<void> updateLoanStatus(String loanId, LoanStatus status) async {
    await _loans.doc(loanId).update({'status': status.name});
  }

  Future<void> deleteLoan(String loanId) async {
    final payments = await _payments(loanId).get();
    final batch = _db.batch();
    for (final doc in payments.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_loans.doc(loanId));
    await batch.commit();
  }

  // ── EMI Payments ───────────────────────────────────────────────────────────

  Stream<List<EmiPayment>> paymentsStream(String loanId) {
    return _payments(loanId)
        .orderBy('emiNumber')
        .snapshots()
        .map((snap) => snap.docs.map(EmiPayment.fromFirestore).toList());
  }

  /// Marks an EMI as paid. Automatically adds ₹100 fine if paid after due date.
  /// No partial payments — always the full EMI amount (+ fine if late).
  Future<void> markEmiPaid(
    String loanId,
    EmiPayment payment, {
    String? remarks,
  }) async {
    final now = DateTime.now();
    final dueDay = DateTime(
        payment.dueDate.year, payment.dueDate.month, payment.dueDate.day);
    final today = DateTime(now.year, now.month, now.day);
    final fine = today.isAfter(dueDay) ? lateFineAmount : 0.0;

    await _payments(loanId).doc(payment.id).update({
      'status': PaymentStatus.paid.name,
      'paidDate': Timestamp.fromDate(now),
      'fineAmount': fine,
      if (remarks != null) 'remarks': remarks,
    });

    // Auto-complete the loan when every EMI is settled.
    final payments = await _payments(loanId).get();
    final allSettled = payments.docs.every(
      (d) =>
          d['status'] == PaymentStatus.paid.name ||
          d['status'] == PaymentStatus.waived.name,
    );
    if (allSettled) await updateLoanStatus(loanId, LoanStatus.completed);
  }

  Future<void> markEmiWaived(
    String loanId,
    String paymentId, {
    String? remarks,
  }) async {
    await _payments(loanId).doc(paymentId).update({
      'status': PaymentStatus.waived.name,
      if (remarks != null) 'remarks': remarks,
    });
  }

  // ── Today's Collection ─────────────────────────────────────────────────────

  /// Returns all pending EMIs due today or already overdue.
  /// Overdue first, then sorted by due date ascending.
  Future<List<DuePayment>> todaysDuePayments() async {
    return _duePaymentsUntil(_endOfToday());
  }

  /// Returns all pending EMIs due within the next 7 days (including today
  /// and overdue). Used for the weekly alert banner.
  Future<List<DuePayment>> weeksDuePayments() async {
    final now = DateTime.now();
    final weekEnd = DateTime(now.year, now.month, now.day + 7);
    return _duePaymentsUntil(weekEnd);
  }

  Future<List<DuePayment>> _duePaymentsUntil(DateTime cutoff) async {
    final loansSnap = await _loans
        .where('status', isEqualTo: LoanStatus.active.name)
        .get();

    final loans = loansSnap.docs.map(Loan.fromFirestore).toList();

    final futures = loans.map((loan) async {
      final snap = await _payments(loan.id)
          .where('status', isEqualTo: PaymentStatus.pending.name)
          .where('dueDate', isLessThan: Timestamp.fromDate(cutoff))
          .get();
      return snap.docs
          .map((d) => DuePayment(loan: loan, payment: EmiPayment.fromFirestore(d)))
          .toList();
    });

    final results = await Future.wait(futures);
    final all = results.expand((e) => e).toList();

    all.sort((a, b) {
      if (a.hasLateFine != b.hasLateFine) return a.hasLateFine ? -1 : 1;
      return a.payment.dueDate.compareTo(b.payment.dueDate);
    });

    return all;
  }

  DateTime _endOfToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  // ── Summary helpers ────────────────────────────────────────────────────────

  Future<Map<String, double>> loanSummary(String loanId) async {
    final payments = await _payments(loanId).get();
    double collected = 0;
    double pending = 0;
    for (final doc in payments.docs) {
      final amount = (doc['amount'] as num).toDouble();
      final fine = (doc['fineAmount'] as num? ?? 0).toDouble();
      final status = doc['status'] as String;
      if (status == PaymentStatus.paid.name ||
          status == PaymentStatus.waived.name) {
        collected += amount + fine;
      } else {
        pending += amount;
      }
    }
    return {'collected': collected, 'pending': pending};
  }

  Future<void> _generateEmiSchedule(Loan loan) async {
    final dueDates = loan.emiDueDates;
    final batch = _db.batch();
    for (int i = 0; i < dueDates.length; i++) {
      final ref = _payments(loan.id).doc();
      final payment = EmiPayment(
        id: ref.id,
        loanId: loan.id,
        emiNumber: i + 1,
        amount: loan.emiAmount,
        dueDate: dueDates[i],
      );
      batch.set(ref, payment.toFirestore());
    }
    await batch.commit();
  }
}
