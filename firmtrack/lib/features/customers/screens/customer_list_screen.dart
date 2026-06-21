import 'package:flutter/material.dart';
import '../../../core/database/database_helper.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _filtered = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    final db = await DatabaseHelper.instance.database;

    final customers = await db.rawQuery('''
      SELECT 
        c.id,
        c.name,
        c.phone,
        c.address,
        c.opening_balance,
        COALESCE(SUM(i.total_amount), 0) AS total_invoiced,
        COALESCE(SUM(p.amount), 0) AS total_paid
      FROM customers c
      LEFT JOIN invoices i ON i.customer_id = c.id
      LEFT JOIN payments p ON p.customer_id = c.id
      GROUP BY c.id
      ORDER BY c.name ASC
    ''');

    setState(() {
      _customers = customers;
      _filtered = customers;
      _isLoading = false;
    });
  }

  void _onSearch(String query) {
    final q = query.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _customers
          : _customers
              .where((c) =>
                  c['name'].toString().toLowerCase().contains(q) ||
                  (c['phone'] ?? '').toString().contains(q))
              .toList();
    });
  }

  Future<void> _deleteCustomer(int id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Delete "\$name"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final db = await DatabaseHelper.instance.database;
      await db.delete('customers', where: 'id = ?', whereArgs: [id]);
      _loadCustomers();
    }
  }

  double _getOutstanding(Map<String, dynamic> c) {
    final opening = (c['opening_balance'] ?? 0.0) as num;
    final invoiced = (c['total_invoiced'] ?? 0.0) as num;
    final paid = (c['total_paid'] ?? 0.0) as num;
    return (opening + invoiced - paid).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomers,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: () async {
          await Navigator.pushNamed(context, '/customer-form');
          _loadCustomers();
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              decoration: InputDecoration(
                hintText: 'Search by name or phone...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearch('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Text('${_filtered.length} customer(s)',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(
                        child: Text('No customers found.',
                            style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) {
                          final c = _filtered[index];
                          final outstanding = _getOutstanding(c);
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo,
                                child: Text(
                                  c['name'].toString()[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(c['name'].toString(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  c['phone'] != null && c['phone'] != ''
                                      ? c['phone'].toString()
                                      : 'No phone'),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${outstanding.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: outstanding > 0
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ),
                                  Text(
                                    outstanding > 0 ? 'Outstanding' : 'Clear',
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.pushNamed(
                                    context, '/customer-form',
                                    arguments: c);
                                _loadCustomers();
                              },
                              onLongPress: () => _deleteCustomer(
                                  c['id'] as int, c['name'].toString()),
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
