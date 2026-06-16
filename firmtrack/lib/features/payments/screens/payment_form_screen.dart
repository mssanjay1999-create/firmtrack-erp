import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';

class PaymentFormScreen extends StatefulWidget {
  const PaymentFormScreen({super.key});

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  final db = DatabaseHelper.instance;
  bool _isLoading = false;
  bool _isInit = false;

  Map<String, dynamic>? _invoice;
  Map<String, dynamic>? _customer;

  String _paymentMode = 'Cash';
  DateTime _selectedDate = DateTime.now();

  final List<String> _paymentModes = ['Cash', 'UPI', 'Cheque', 'Bank Transfer'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        _invoice = args;
        _loadCustomer();
      }
    }
  }

  Future<void> _loadCustomer() async {
    if (_invoice == null) return;
    final database = await db.database;
    final result = await database.query(
      'customers',
      where: 'id = ?',
      whereArgs: [_invoice!['customer_id']],
    );
    if (result.isNotEmpty) {
      setState(() => _customer = result.first);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _savePayment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_invoice == null) return;

    final amount = double.parse(_amountController.text.trim());
    final balance = (_invoice!['balance_amount'] as num).toDouble();

    if (amount > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount cannot exceed invoice balance'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final database = await db.database;

      await database.transaction((txn) async {
        await txn.insert('payments', {
          'invoice_id': _invoice!['id'],
          'customer_id': _invoice!['customer_id'],
          'amount': amount,
          'payment_mode': _paymentMode,
          'payment_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
          'notes': _notesController.text.trim(),
          'created_at': DateTime.now().toIso8601String(),
        });

        final newBalance = balance - amount;
        final newStatus = newBalance <= 0 ? 'Paid' : 'Partially Paid';

        await txn.update(
          'invoices',
          {'balance_amount': newBalance, 'status': newStatus},
          where: 'id = ?',
          whereArgs: [_invoice!['id']],
        );

        final custBalance = (_customer!['outstanding_balance'] as num).toDouble();
        await txn.update(
          'customers',
          {'outstanding_balance': custBalance - amount},
          where: 'id = ?',
          whereArgs: [_invoice!['customer_id']],
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment saved successfully'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: \$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_invoice == null) {
      return const Scaffold(body: Center(child: Text('No invoice selected')));
    }

    final totalAmount = (_invoice!['total_amount'] as num).toDouble();
    final balanceAmount = (_invoice!['balance_amount'] as num).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Record Payment'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: const Color(0xFFE3F2FD),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _customer?['name'] ?? '',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text('Invoice #${_invoice!["invoice_number"]}'),
                      const SizedBox(height: 4),
                      Text('Invoice Date: ${_invoice!["invoice_date"]}'),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Amount:'),
                          Text("₹${totalAmount.toStringAsFixed(2)}"),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Balance Due:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            "₹${balanceAmount.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Payment Amount *',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter amount';
                  final val = double.tryParse(v.trim());
                  if (val == null || val <= 0) return 'Enter valid amount';
                  if (val > balanceAmount) return "Cannot exceed balance ₹${balanceAmount.toStringAsFixed(2)}";
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _paymentMode,
                decoration: const InputDecoration(
                  labelText: 'Payment Mode *',
                  border: OutlineInputBorder(),
                ),
                items: _paymentModes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (v) => setState(() => _paymentMode = v!),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment Date *',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Payment', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
