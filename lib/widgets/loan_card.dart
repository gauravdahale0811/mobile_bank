import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';

class LoanCard extends StatelessWidget {
  final Loan loan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const LoanCard({
    super.key,
    required this.loan,
    required this.onTap,
    required this.onDelete,
  });

  Color _statusColor() {
    switch (loan.status) {
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
    final fmt = DateFormat('dd MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    child: Text(
                      loan.borrowerName[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loan.borrowerName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          loan.borrowerPhone,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _statusColor().withValues(alpha: 0.15),
                      border: Border.all(color: _statusColor()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      loan.status.label,
                      style: TextStyle(
                          fontSize: 11,
                          color: _statusColor(),
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: onDelete,
                    color: Colors.red,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoChip(
                    label: 'Principal',
                    value: '₹${loan.principal.toStringAsFixed(0)}',
                  ),
                  _InfoChip(
                    label: 'Total',
                    value: '₹${loan.totalRepayment.toStringAsFixed(0)}',
                  ),
                  _InfoChip(
                    label: 'EMI',
                    value:
                        '₹${loan.emiAmount.toStringAsFixed(0)}/${loan.frequency.label.toLowerCase()}',
                  ),
                  _InfoChip(
                    label: 'EMIs',
                    value: '${loan.numberOfEmis}',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Disbursed: ${fmt.format(loan.disbursementDate)}',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
