import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedgerScreenState();
}

class _CustomerLedgerScreenState extends State<CustomerLedgerScreen> {
  final db = DatabaseHelper.instance;
  bool _isLoading = true;
  bool _isInit = false;

  Map<String, dynamic>? _customer;
  List<Map<String, dynamic>> _entries = [];
  double _runningBalance = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      _isInit = true;
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map<String, dynamic>) {
        _customer = args;
        _loadLedger();
      }
    }
  }

  Future<void> _loadLedger() async {
    if (_customer == null) return;
    setState(() => _isLoading = true);

    final database = await db.database;
    final customerId = _customer!['id'];

    final invoices = await database.query(
      'invoices',
      where: 'customer_id = ? AND status != ?',
      whereArgs: [customerId, 'Cancelled'],
      orderBy: 'invoice_date ASC',
    );

    final payments = await database.query(
      'payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'payment_date ASC',
    );

    List<Map<String, dynamic>> entries = [];

    for (var inv in invoices) {
      entries.add({
        'type': 'invoice',
        'date': inv['invoice_date'],
        'description': 'Invoice #${inv["invoice_number"]}',
        'debit': inv['total_amount'],
        'credit': 0.0,
        'status': inv['status'],
      });
    }

    for (var pay in payments) {
      entries.add({
        'type': 'payment',
        'date': pay['payment_date'],
        'description': 'Payment (${pay["payment_mode"]})',
        'debit': 0.0,
        'credit': pay['amount'],
        'status': '',
      });
    }

    entries.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

    double opening = (_customer!['opening_balance'] as num).toDouble();
    double running = opening;

    List<Map<String, dynamic>> finalEntries = [];

    finalEntries.add({
      'type': 'opening',
      'date': '',
      'description': 'Opening Balance',
      'debit': opening,
      'credit': 0.0,
      'balance': opening,
      'status': '',
    });

    for (var e in entries) {
      running += (e['debit'] as num).toDouble();
      running -= (e['credit'] as num).toDouble();
      finalEntries.add({...e, 'balance': running});
    }

    setState(() {
      _entries = finalEntries;
      _runningBalance = running;
      _isLoading = false;
    });
  }

  Color _balanceColor(double balance) {
    if (balance > 0) return Colors.red;
    if (balance < 0) return Colors.green;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    if (_customer == null) {
      return const Scaffold(body: Center(child: Text('No customer selected')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer!['name'] ?? 'Customer Ledger'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Summary card
                Container(
                  width: double.infinity,
                  color: const Color(0xFF1976D2),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Outstanding Balance:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(
                            '₹${_runningBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _balanceColor(_runningBalance),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Table header
                Container(
                  color: Colors.grey[200],
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 4, child: Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Expanded(flex: 2, child: Text('Debit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('Credit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                      Expanded(flex: 2, child: Text('Balance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.right)),
                    ],
                  ),
                ),

                // Ledger rows
                Expanded(
                  child: _entries.isEmpty
                      ? const Center(child: Text('No transactions found'))
                      : ListView.builder(
                          itemCount: _entries.length,
                          itemBuilder: (context, index) {
                            final e = _entries[index];
                            final debit = (e['debit'] as num).toDouble();
                            final credit = (e['credit'] as num).toDouble();
                            final balance = (e['balance'] as num).toDouble();
                            final isInvoice = e['type'] == 'invoice';
                            final isOpening = e['type'] == 'opening';

                            return Container(
                              decoration: BoxDecoration(
                                color: index % 2 == 0 ? Colors.white : Colors.grey[50],
                                border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      e['date'].toString().isNotEmpty
                                          ? DateFormat('dd/MM/yy').format(DateTime.parse(e['date']))
                                          : '',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e['description'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isOpening ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                        if (isInvoice && e['status'].toString().isNotEmpty)
                                          Text(
                                            e['status'],
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: e['status'] == 'Paid' ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      debit > 0 ? '₹${debit.toStringAsFixed(0)}' : '',
                                      style: const TextStyle(fontSize: 11, color: Colors.red),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      credit > 0 ? '₹${credit.toStringAsFixed(0)}' : '',
                                      style: const TextStyle(fontSize: 11, color: Colors.green),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      '₹${balance.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _balanceColor(balance),
                                      ),
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
