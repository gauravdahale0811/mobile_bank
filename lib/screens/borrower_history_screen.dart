import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../services/firestore_service.dart';
import '../widgets/loan_card.dart';
import 'loan_detail_screen.dart';

class BorrowerHistoryScreen extends StatelessWidget {
  final String borrowerName;
  final String borrowerPhone;

  const BorrowerHistoryScreen({
    super.key,
    required this.borrowerName,
    required this.borrowerPhone,
  });

  @override
  Widget build(BuildContext context) {
    final service = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(borrowerName),
            Text(
              '+91 $borrowerPhone',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<Loan>>(
        stream: service.loansForBorrower(borrowerPhone),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final loans = snapshot.data ?? [];

          if (loans.isEmpty) {
            return const Center(child: Text('No loans found for this borrower.'));
          }

          // Aggregate stats
          final totalPrincipal =
              loans.fold(0.0, (s, l) => s + l.principal);
          final totalRepayable =
              loans.fold(0.0, (s, l) => s + l.totalRepayment);
          final active =
              loans.where((l) => l.status == LoanStatus.active).length;
          final completed =
              loans.where((l) => l.status == LoanStatus.completed).length;

          return Column(
            children: [
              _BorrowerSummaryHeader(
                loanCount: loans.length,
                active: active,
                completed: completed,
                totalPrincipal: totalPrincipal,
                totalRepayable: totalRepayable,
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: loans.length,
                  itemBuilder: (context, i) {
                    return LoanCard(
                      loan: loans[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoanDetailScreen(loan: loans[i]),
                        ),
                      ),
                      onDelete: () =>
                          _confirmDelete(context, service, loans[i]),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FirestoreService service,
    Loan loan,
  ) async {
    final fmt = DateFormat('dd MMM yyyy');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Loan'),
        content: Text(
          'Delete the ₹${loan.principal.toStringAsFixed(0)} loan '
          'disbursed on ${fmt.format(loan.disbursementDate)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await service.deleteLoan(loan.id);
    }
  }
}

class _BorrowerSummaryHeader extends StatelessWidget {
  final int loanCount;
  final int active;
  final int completed;
  final double totalPrincipal;
  final double totalRepayable;

  const _BorrowerSummaryHeader({
    required this.loanCount,
    required this.active,
    required this.completed,
    required this.totalPrincipal,
    required this.totalRepayable,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat('Total Loans', '$loanCount'),
              _Stat('Active', '$active',
                  color: active > 0 ? Colors.green : null),
              _Stat('Completed', '$completed',
                  color: completed > 0 ? Colors.blue : null),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat('Total Lent',
                  '₹${totalPrincipal.toStringAsFixed(0)}'),
              _Stat('Total Repayable',
                  '₹${totalRepayable.toStringAsFixed(0)}',
                  bold: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  const _Stat(this.label, this.value, {this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: 17,
            color: color,
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
