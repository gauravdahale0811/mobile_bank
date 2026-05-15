import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/loan.dart';
import '../services/firestore_service.dart';
import '../utils/emi_calculator.dart';

// Fixed loan tiers: principal → total repayment (interest = ₹1000 per ₹5000)
const _loanTiers = [
  _LoanTier(principal: 5000, totalRepayment: 6000),
  _LoanTier(principal: 10000, totalRepayment: 12000),
  _LoanTier(principal: 15000, totalRepayment: 18000),
  _LoanTier(principal: 20000, totalRepayment: 24000),
];

class _LoanTier {
  final double principal;
  final double totalRepayment;

  const _LoanTier({required this.principal, required this.totalRepayment});

  double get interest => totalRepayment - principal;
}

class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  _LoanTier _selectedTier = _loanTiers.first;

  // Duration is fixed at 2 months for all loans.
  static const int _durationMonths = 2;

  PaymentFrequency _frequency = PaymentFrequency.weekly;
  DateTime _disbursementDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _emiCount => EmiCalculator.numberOfEmis(_durationMonths, _frequency);

  double get _emiAmount =>
      EmiCalculator.emiAmount(_selectedTier.totalRepayment, _durationMonths, _frequency);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _disbursementDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _disbursementDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final loan = Loan(
        id: '',
        borrowerName: _nameCtrl.text.trim(),
        borrowerPhone: _phoneCtrl.text.trim(),
        principal: _selectedTier.principal,
        totalRepayment: _selectedTier.totalRepayment,
        durationMonths: _durationMonths,
        frequency: _frequency,
        disbursementDate: _disbursementDate,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );
      await context.read<FirestoreService>().addLoan(loan);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('New Loan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Borrower ────────────────────────────────────────────────────
              _section('Borrower Details'),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Borrower Name',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),

              const SizedBox(height: 20),

              // ── Loan amount ─────────────────────────────────────────────────
              _section('Loan Amount'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.2,
                children: _loanTiers.map((tier) {
                  final selected = tier == _selectedTier;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTier = tier),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      decoration: BoxDecoration(
                        color: selected ? cs.primary : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? cs.primary : cs.outline,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '₹${tier.principal.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: selected ? Colors.white : cs.onSurface,
                            ),
                          ),
                          Text(
                            '+₹${tier.interest.toStringAsFixed(0)} interest',
                            style: TextStyle(
                              fontSize: 11,
                              color: selected ? Colors.white70 : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── Repayment terms ─────────────────────────────────────────────
              _section('Repayment Terms'),

              // Duration: fixed 2 months — show as read-only
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  border: Border.all(color: cs.outline),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month, size: 20, color: cs.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Duration',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        const Text('2 months (fixed)',
                            style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentFrequency>(
                value: _frequency,
                decoration: const InputDecoration(
                  labelText: 'EMI Frequency',
                  prefixIcon: Icon(Icons.repeat),
                ),
                items: PaymentFrequency.values
                    .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _frequency = v ?? PaymentFrequency.weekly),
              ),

              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Disbursement Date'),
                subtitle: Text(
                  '${_disbursementDate.day}/${_disbursementDate.month}/${_disbursementDate.year}',
                ),
                trailing:
                    TextButton(onPressed: _pickDate, child: const Text('Change')),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 20),

              // ── EMI summary ─────────────────────────────────────────────────
              _EmiSummaryCard(
                tier: _selectedTier,
                emiAmount: _emiAmount,
                emiCount: _emiCount,
                frequency: _frequency,
              ),

              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: const Text('Create Loan'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmiSummaryCard extends StatelessWidget {
  final _LoanTier tier;
  final double emiAmount;
  final int emiCount;
  final PaymentFrequency frequency;

  const _EmiSummaryCard({
    required this.tier,
    required this.emiAmount,
    required this.emiCount,
    required this.frequency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Loan Summary',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _row('Principal', '₹${tier.principal.toStringAsFixed(0)}'),
          _row('Interest (flat)', '₹${tier.interest.toStringAsFixed(0)}'),
          _row('Duration', '2 months'),
          const Divider(height: 16),
          _row('Total Repayment', '₹${tier.totalRepayment.toStringAsFixed(0)}',
              bold: true),
          const SizedBox(height: 8),
          _row('Per EMI (${frequency.label})', '₹${emiAmount.toStringAsFixed(2)}',
              bold: true),
          _row('Number of EMIs', '$emiCount'),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}
