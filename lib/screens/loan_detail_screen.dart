import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/emi_payment.dart';
import '../services/firestore_service.dart';
import '../widgets/emi_tile.dart';
import 'edit_loan_screen.dart';

class LoanDetailScreen extends StatelessWidget {
  final Loan loan;

  const LoanDetailScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();
    final fmt = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(loan.borrowerName),
        actions: [
          // Edit borrower details
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => EditLoanScreen(loan: loan)),
            ),
          ),
          // Change loan status
          PopupMenuButton<LoanStatus>(
            tooltip: 'Change status',
            onSelected: (status) =>
                service.updateLoanStatus(loan.id, status),
            itemBuilder: (_) => LoanStatus.values
                .map((s) => PopupMenuItem(
                      value: s,
                      child: Text(s.label),
                    ))
                .toList(),
          ),
        ],
      ),
      body: Column(
        children: [
          _LoanSummaryHeader(loan: loan, fmt: fmt),
          const Divider(height: 1),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'EMI Schedule',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                _CollectedBadge(loanId: loan.id, service: service),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<EmiPayment>>(
              stream: service.paymentsStream(loan.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final payments = snapshot.data ?? [];
                if (payments.isEmpty) {
                  return const Center(child: Text('No EMI schedule found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: payments.length,
                  itemBuilder: (context, i) {
                    return EmiTile(
                      payment: payments[i],
                      onMarkPaid: () =>
                          _markPaid(context, service, payments[i]),
                      onMarkWaived: () => service.markEmiWaived(
                          loan.id, payments[i].id),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _markPaid(
    BuildContext context,
    FirestoreService service,
    EmiPayment payment,
  ) async {
    final remarksCtrl = TextEditingController();
    final isLate = payment.isOverdue;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Collect EMI #${payment.emiNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _amountRow('EMI amount', payment.amount),
            if (isLate)
              _amountRow('Late fine', lateFineAmount, color: Colors.red),
            const Divider(),
            _amountRow(
              'Total',
              payment.amount + (isLate ? lateFineAmount : 0),
              bold: true,
            ),
            if (isLate)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '₹100 fine applied — EMI is overdue.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksCtrl,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Collect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await service.markEmiPaid(
        loan.id,
        payment,
        remarks: remarksCtrl.text.trim().isEmpty
            ? null
            : remarksCtrl.text.trim(),
      );
    }
  }

  Widget _amountRow(String label, double amount,
      {Color? color, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanSummaryHeader extends StatelessWidget {
  final Loan loan;
  final DateFormat fmt;

  const _LoanSummaryHeader({required this.loan, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.primaryContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.phone, size: 16),
              const SizedBox(width: 6),
              Text(loan.borrowerPhone),
              const Spacer(),
              _StatusChip(status: loan.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountTile(
                  label: 'Principal',
                  value: '₹${loan.principal.toStringAsFixed(0)}'),
              _AmountTile(
                  label: 'Interest',
                  value: '₹${loan.interest.toStringAsFixed(0)}'),
              _AmountTile(
                  label: 'Total',
                  value: '₹${loan.totalRepayment.toStringAsFixed(0)}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountTile(
                  label: 'EMI',
                  value: '₹${loan.emiAmount.toStringAsFixed(0)}'),
              _AmountTile(
                  label: 'Total EMIs',
                  value: '${loan.numberOfEmis} ${loan.frequency.label}'),
              _AmountTile(
                  label: 'Disbursed',
                  value: fmt.format(loan.disbursementDate)),
            ],
          ),
          if (loan.notes != null && loan.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Note: ${loan.notes}',
              style: const TextStyle(
                  fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final String value;

  const _AmountTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final LoanStatus status;

  const _StatusChip({required this.status});

  Color _color() {
    switch (status) {
      case LoanStatus.active:
        return Colors.green;
      case LoanStatus.completed:
        return Colors.blue;
      case LoanStatus.defaulted:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status.label, style: const TextStyle(fontSize: 11)),
      backgroundColor: _color().withValues(alpha: 0.15),
      side: BorderSide(color: _color()),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}

class _CollectedBadge extends StatelessWidget {
  final String loanId;
  final FirestoreService service;

  const _CollectedBadge({required this.loanId, required this.service});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, double>>(
      future: service.loanSummary(loanId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final collected = snapshot.data!['collected'] ?? 0;
        final pending = snapshot.data!['pending'] ?? 0;
        return Text(
          'Collected ₹${collected.toStringAsFixed(0)} / Pending ₹${pending.toStringAsFixed(0)}',
          style: Theme.of(context).textTheme.labelSmall,
        );
      },
    );
  }
}
