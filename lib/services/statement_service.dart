import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/loan.dart';
import '../models/emi_payment.dart';

class StatementService {
  static final _dateFmt = DateFormat('dd MMM yyyy');
  static final _nowFmt = DateFormat('dd MMM yyyy, hh:mm a');

  // ── Public entry point ────────────────────────────────────────────────────

  /// Generates a PDF statement for [loan] + [payments] and opens the OS
  /// share / print sheet via the [printing] package.
  static Future<void> shareStatement({
    required Loan loan,
    required List<EmiPayment> payments,
    required String lenderPhone,
  }) async {
    final pdf = await _buildPdf(loan: loan, payments: payments, lenderPhone: lenderPhone);
    await Printing.sharePdf(
      bytes: pdf,
      filename: 'loan_statement_${loan.borrowerPhone}_${loan.id.substring(0, 6)}.pdf',
    );
  }

  // ── PDF construction ──────────────────────────────────────────────────────

  static Future<Uint8List> _buildPdf({
    required Loan loan,
    required List<EmiPayment> payments,
    required String lenderPhone,
  }) async {
    final doc = pw.Document();

    // Pre-compute totals
    final paidPayments =
        payments.where((p) => p.status == PaymentStatus.paid).toList();
    final waivedPayments =
        payments.where((p) => p.status == PaymentStatus.waived).toList();
    final pendingPayments =
        payments.where((p) => p.status == PaymentStatus.pending).toList();

    final totalCollected =
        paidPayments.fold(0.0, (s, p) => s + p.totalCollected);
    final totalWaived =
        waivedPayments.fold(0.0, (s, p) => s + p.amount);
    final totalPending =
        pendingPayments.fold(0.0, (s, p) => s + p.amount);
    final totalFines =
        paidPayments.fold(0.0, (s, p) => s + p.fineAmount);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (_) => _header(loan, lenderPhone),
        footer: (_) => _footer(),
        build: (ctx) => [
          pw.SizedBox(height: 16),
          _loanTermsSection(loan),
          pw.SizedBox(height: 20),
          _emiScheduleSection(payments),
          pw.SizedBox(height: 20),
          _summarySection(
            totalCollected: totalCollected,
            totalFines: totalFines,
            totalWaived: totalWaived,
            totalPending: totalPending,
            paidCount: paidPayments.length,
            waivedCount: waivedPayments.length,
            pendingCount: pendingPayments.length,
          ),
        ],
      ),
    );

    return doc.save();
  }

  // ── Header ────────────────────────────────────────────────────────────────

  static pw.Widget _header(Loan loan, String lenderPhone) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'MICROFINANCE',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                  ),
                ),
                pw.Text(
                  'Loan Statement',
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Generated: ${_nowFmt.format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
                pw.Text('Lender: +91 $lenderPhone',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey)),
              ],
            ),
          ],
        ),
        pw.Divider(color: PdfColors.blue800, thickness: 1.5),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Text('Borrower: ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('${loan.borrowerName}  |  +91 ${loan.borrowerPhone}'),
          ],
        ),
        pw.SizedBox(height: 4),
      ],
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  static pw.Widget _footer() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400),
        pw.Text(
          'This is a computer-generated statement. No signature required.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  // ── Loan terms section ────────────────────────────────────────────────────

  static pw.Widget _loanTermsSection(Loan loan) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('LOAN TERMS'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            _tableRow(
              ['Principal', 'Interest', 'Total Repayment', 'Duration'],
              isHeader: true,
            ),
            _tableRow([
              '₹${loan.principal.toStringAsFixed(0)}',
              '₹${loan.interest.toStringAsFixed(0)}',
              '₹${loan.totalRepayment.toStringAsFixed(0)}',
              '${loan.durationMonths} months',
            ]),
            _tableRow(
              ['EMI Amount', 'Frequency', 'Total EMIs', 'Disbursed On'],
              isHeader: true,
            ),
            _tableRow([
              '₹${loan.emiAmount.toStringAsFixed(2)}',
              loan.frequency.label,
              '${loan.numberOfEmis}',
              _dateFmt.format(loan.disbursementDate),
            ]),
          ],
        ),
        if (loan.notes != null && loan.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('Note: ${loan.notes}',
              style: pw.TextStyle(
                  fontSize: 9,
                  fontStyle: pw.FontStyle.italic,
                  color: PdfColors.grey700)),
        ],
      ],
    );
  }

  // ── EMI schedule section ──────────────────────────────────────────────────

  static pw.Widget _emiScheduleSection(List<EmiPayment> payments) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('EMI SCHEDULE'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FixedColumnWidth(28),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(1.5),
            3: const pw.FlexColumnWidth(1.2),
            4: const pw.FlexColumnWidth(1.5),
            5: const pw.FlexColumnWidth(2),
          },
          children: [
            _tableRow(
              ['#', 'Due Date', 'Amount', 'Fine', 'Status', 'Paid On'],
              isHeader: true,
            ),
            ...payments.map((p) => _emiRow(p)),
          ],
        ),
      ],
    );
  }

  static pw.TableRow _emiRow(EmiPayment p) {
    final statusColor = _statusColor(p.status);
    return pw.TableRow(
      children: [
        _cell('${p.emiNumber}'),
        _cell(_dateFmt.format(p.dueDate)),
        _cell('₹${p.amount.toStringAsFixed(0)}'),
        _cell(p.fineAmount > 0 ? '₹${p.fineAmount.toStringAsFixed(0)}' : '—',
            color: p.fineAmount > 0 ? PdfColors.red : null),
        _cell(p.status.label, color: statusColor),
        _cell(p.paidDate != null ? _dateFmt.format(p.paidDate!) : '—'),
      ],
    );
  }

  // ── Summary section ───────────────────────────────────────────────────────

  static pw.Widget _summarySection({
    required double totalCollected,
    required double totalFines,
    required double totalWaived,
    required double totalPending,
    required int paidCount,
    required int waivedCount,
    required int pendingCount,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('COLLECTION SUMMARY'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.5),
            2: const pw.FlexColumnWidth(2),
          },
          children: [
            _tableRow(['Description', 'EMIs', 'Amount'], isHeader: true),
            _tableRow(['Collected (incl. fines)', '$paidCount',
                '₹${totalCollected.toStringAsFixed(0)}']),
            if (totalFines > 0)
              _tableRow(['  of which Late Fines', '—',
                  '₹${totalFines.toStringAsFixed(0)}'],
                  color: PdfColors.red50),
            if (waivedCount > 0)
              _tableRow(['Waived', '$waivedCount',
                  '₹${totalWaived.toStringAsFixed(0)}']),
            _tableRow(['Pending', '$pendingCount',
                '₹${totalPending.toStringAsFixed(0)}'],
                color: pendingCount > 0 ? PdfColors.orange50 : null),
          ],
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      color: PdfColors.blue50,
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 10,
          color: PdfColors.blue800,
          letterSpacing: 1,
        ),
      ),
    );
  }

  static pw.TableRow _tableRow(
    List<String> cells, {
    bool isHeader = false,
    PdfColor? color,
  }) {
    return pw.TableRow(
      decoration: isHeader
          ? const pw.BoxDecoration(color: PdfColors.blue800)
          : color != null
              ? pw.BoxDecoration(color: color)
              : null,
      children: cells
          .map((c) => _cell(c,
              isHeader: isHeader,
              color: isHeader ? PdfColors.white : null))
          .toList(),
    );
  }

  static pw.Widget _cell(
    String text, {
    bool isHeader = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    );
  }

  static PdfColor _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return PdfColors.green700;
      case PaymentStatus.waived:
        return PdfColors.blue700;
      case PaymentStatus.pending:
        return PdfColors.orange700;
    }
  }
}
