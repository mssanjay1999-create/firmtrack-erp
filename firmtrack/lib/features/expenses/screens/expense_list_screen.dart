import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';
import 'package:intl/intl.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final DatabaseHelper _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _expenses = [];
  String _selectedCategory = 'All';
  double _totalAmount = 0.0;
  bool _isLoading = true;

  final List<String> _categories = [
    'All',
    'Raw Material',
    'Labour Salary',
    'Transport',
    'Rent',
    'Electricity',
    'Miscellaneous',
  ];

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    setState(() => _isLoading = true);
    final db = await _db.database;
    List<Map<String, dynamic>> results;
    if (_selectedCategory == 'All') {
      results = await db.query('expenses', orderBy: 'expense_date DESC');
    } else {
      results = await db.query(
        'expenses',
        where: 'category = ?',
        whereArgs: [_selectedCategory],
        orderBy: 'expense_date DESC',
      );
    }
    double total = 0.0;
    for (final e in results) {
      total += (e['amount'] as num).toDouble();
    }
    setState(() {
      _expenses = results;
      _totalAmount = total;
      _isLoading = false;
    });
  }

  String _formatAmount(double amount) {
    final fmt = NumberFormat('##,##,##0.00', 'en_IN');
    return fmt.format(amount);
  }

  Future<void> _deleteExpense(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text('Are you sure you want to delete this expense?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final db = await _db.database;
      await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
      _loadExpenses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted')),
        );
      }
    }
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'Raw Material': return Colors.blue;
      case 'Labour Salary': return Colors.purple;
      case 'Transport': return Colors.orange;
      case 'Rent': return Colors.red;
      case 'Electricity': return Colors.amber;
      case 'Miscellaneous': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF1976D2),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedCategory == 'All' ? 'Total Expenses' : '$_selectedCategory Total',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    Text(
                      '${String.fromCharCode(8377)} ${_formatAmount(_totalAmount)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length,
              itemBuilder: (ctx, index) {
                final cat = _categories[index];
                final selected = _selectedCategory == cat;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedCategory = cat);
                    _loadExpenses();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF1976D2) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _expenses.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text(
                              _selectedCategory == 'All'
                                  ? 'No expenses recorded'
                                  : 'No $_selectedCategory expenses',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _expenses.length,
                        itemBuilder: (ctx, index) {
                          final expense = _expenses[index];
                          final isLabourSalary = expense['category'] == 'Labour Salary';
                          final category = expense['category'] as String;
                          final expAmount = (expense['amount'] as num).toDouble();
                          final date = expense['expense_date'] as String;
                          final notes = expense['note'] as String? ?? '';
                          const paidBy = '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _categoryColor(category).withAlpha(26),
                                child: Icon(
                                  isLabourSalary ? Icons.people : Icons.receipt,
                                  color: _categoryColor(category),
                                  size: 20,
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      category,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    '${String.fromCharCode(8377)} ${_formatAmount(expAmount)}',
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        DateFormat('dd MMM yyyy').format(DateTime.parse(date)),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      if (paidBy.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade200,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(paidBy, style: const TextStyle(fontSize: 10)),
                                        ),
                                      ],
                                      if (isLabourSalary) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.purple.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text(
                                            'Auto',
                                            style: TextStyle(fontSize: 10, color: Colors.purple),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (notes.isNotEmpty)
                                    Text(
                                      notes,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                              trailing: isLabourSalary
                                  ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                                  : PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          Navigator.pushNamed(
                                            context,
                                            '/expense-form',
                                            arguments: expense,
                                          ).then((_) => _loadExpenses());
                                        } else if (value == 'delete') {
                                          _deleteExpense(expense['id'] as int);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                                        ),
                                      ],
                                    ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/expense-form').then((_) => _loadExpenses());
        },
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}
