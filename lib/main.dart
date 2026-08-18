import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

void main() {
  runApp(const SalesApp());
}

class SalesApp extends StatelessWidget {
  const SalesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sales & Debt Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3F51B5),
          primary: const Color(0xFF3F51B5),
          surface: const Color(0xFFF8F9FA),
        ),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const MainDashboard(),
    );
  }
}

class ProductItem {
  String name;
  double price;
  int quantity;

  ProductItem({required this.name, required this.price, required this.quantity});

  Map<String, dynamic> toJson() => {'name': name, 'price': price, 'quantity': quantity};
  factory ProductItem.fromJson(Map<String, dynamic> json) => ProductItem(
        name: json['name'],
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'],
      );
}

class Order {
  String id;
  DateTime date;
  List<ProductItem> items;
  double totalAmount;

  Order({required this.id, required this.date, required this.items, required this.totalAmount});

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
        'totalAmount': totalAmount,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'],
        date: DateTime.parse(json['date']),
        items: (json['items'] as List).map((e) => ProductItem.fromJson(e)).toList(),
        totalAmount: (json['totalAmount'] as num).toDouble(),
      );
}

class ClientObject {
  String id;
  String name;
  String category;
  DateTime dueDate;
  bool isPaid;
  List<Order> orders;

  ClientObject({
    required this.id,
    required this.name,
    required this.category,
    required this.dueDate,
    this.isPaid = false,
    required this.orders,
  });

  double get totalDebt {
    if (isPaid) return 0.0;
    return orders.fold(0.0, (sum, item) => sum + item.totalAmount);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'dueDate': dueDate.toIso8601String(),
        'isPaid': isPaid,
        'orders': orders.map((e) => e.toJson()).toList(),
      };

  factory ClientObject.fromJson(Map<String, dynamic> json) => ClientObject(
        id: json['id'],
        name: json['name'],
        category: json['category'],
        dueDate: DateTime.parse(json['dueDate']),
        isPaid: json['isPaid'],
        orders: (json['orders'] as List).map((e) => Order.fromJson(e)).toList(),
      );
}

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  List<ClientObject> _clients = [];
  Map<String, double> _productCatalog = {};
  String _selectedCategory = 'ყველა';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final String clientsData = jsonEncode(_clients.map((e) => e.toJson()).toList());
    final String catalogData = jsonEncode(_productCatalog);
    await prefs.setString('clients_data', clientsData);
    await prefs.setString('catalog_data', catalogData);
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? clientsData = prefs.getString('clients_data');
    final String? catalogData = prefs.getString('catalog_data');

    if (clientsData != null) {
      final List decoded = jsonDecode(clientsData);
      setState(() {
        _clients = decoded.map((e) => ClientObject.fromJson(e)).toList();
      });
    }

    if (catalogData != null) {
      final Map<String, dynamic> decodedCatalog = jsonDecode(catalogData);
      setState(() {
        _productCatalog = decodedCatalog.map((key, value) => MapEntry(key, (value as num).toDouble()));
      });
    }
  }

  void _addClient(String name, String category, DateTime dueDate) {
    setState(() {
      _clients.add(ClientObject(
        id: DateTime.now().toString(),
        name: name,
        category: category,
        dueDate: dueDate,
        orders: [],
      ));
    });
    _saveData();
  }

  void _togglePaid(ClientObject client) {
    setState(() {
      client.isPaid = !client.isPaid;
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
    final filteredClients = _selectedCategory == 'ყველა'
        ? _clients
        : _clients.where((c) => c.category == _selectedCategory).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ობიექტები & დავალიანებები', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['ყველა', 'რესტორანი', 'კაფე', 'სასტუმრო'].map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  onSelected: (selected) => setState(() => _selectedCategory = cat),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: filteredClients.isEmpty
                ? const Center(child: Text('ობიექტები არ არის დამატებული'))
                : ListView.builder(
                    itemCount: filteredClients.length,
                    padding: const EdgeInsets.all(12),
                    itemBuilder: (ctx, i) {
                      final client = filteredClients[i];
                      final isOverdue = DateTime.now().isAfter(client.dueDate) && !client.isPaid;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: client.category == 'რესტორანი'
                                ? Colors.orange[100]
                                : client.category == 'კაფე'
                                    ? Colors.brown[100]
                                    : Colors.blue[100],
                            child: Icon(
                              client.category == 'რესტორანი'
                                  ? Icons.restaurant
                                  : client.category == 'კაფე'
                                      ? Icons.local_cafe
                                      : Icons.hotel,
                              color: Colors.black87,
                            ),
                          ),
                          title: Text(client.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 6),
                              Text('ვადა: ${client.dueDate.toString().split(' ')[0]}',
                                  style: TextStyle(color: isOverdue ? Colors.red : Colors.grey[700], fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal)),
                              Text('დავალიანება: ${client.totalDebt.toStringAsFixed(2)} ₾',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(client.isPaid ? Icons.check_circle : Icons.pending_actions,
                                    color: client.isPaid ? Colors.green : Colors.orange, size: 28),
                                onPressed: () => _togglePaid(client),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ClientDetailScreen(
                                  client: client,
                                  catalog: _productCatalog,
                                  onSave: _saveData,
                                ),
                              ),
                            );
                            setState(() {});
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddClientDialog,
        label: const Text('ობიექტის დამატება'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _showAddClientDialog() {
    final nameCtrl = TextEditingController();
    String category = 'რესტორანი';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('ახალი ობიექტის დამატება'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'ობიექტის/შპს დასახელება')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: category,
                items: ['რესტორანი', 'კაფე', 'სასტუმრო'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDlgState(() => category = v!),
                decoration: const InputDecoration(labelText: 'კატეგორია'),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: Text('გადახდის ვადა: ${selectedDate.toString().split(' ')[0]}')),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setDlgState(() => selectedDate = picked);
                    },
                    child: const Text('არჩევა'),
                  )
                ],
              )
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('გაუქმება')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty) {
                  _addClient(nameCtrl.text, category, selectedDate);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('შენახვა'),
            ),
          ],
        ),
      ),
    );
  }
}

class ClientDetailScreen extends StatefulWidget {
  final ClientObject client;
  final Map<String, double> catalog;
  final VoidCallback onSave;

  const ClientDetailScreen({super.key, required this.client, required this.catalog, required this.onSave});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  void _addOrder(List<ProductItem> items) {
    final total = items.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
    setState(() {
      widget.client.orders.insert(
        0,
        Order(id: DateTime.now().toString(), date: DateTime.now(), items: items, totalAmount: total),
      );
      for (var item in items) {
        widget.catalog[item.name] = item.price;
      }
    });
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.client.name)),
      body: widget.client.orders.isEmpty
          ? const Center(child: Text('შეკვეთების ისტორია ცარიელია'))
          : ListView.builder(
              itemCount: widget.client.orders.length,
              padding: const EdgeInsets.all(12),
              itemBuilder: (ctx, i) {
                final order = widget.client.orders[i];
                return Card(
                  child: ExpansionTile(
                    title: Text('შეკვეთა: ${order.date.toString().split(' ')[0]}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('ჯამი: ${order.totalAmount.toStringAsFixed(2)} ₾', style: const TextStyle(color: Colors.indigo)),
                    children: order.items
                        .map((item) => ListTile(
                              title: Text(item.name),
                              subtitle: Text('${item.quantity} ცალი  x  ${item.price} ₾'),
                              trailing: Text('${(item.quantity * item.price).toStringAsFixed(2)} ₾'),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOrderDialog,
        label: const Text('ახალი შეკვეთა'),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }

  void _showAddOrderDialog() {
    List<ProductItem> orderItems = [];
    final prodNameCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Text('ახალი შეკვეთის აწყობა'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Autocomplete<String>(
                  optionsBuilder: (textValue) {
                    if (textValue.text == '') return widget.catalog.keys;
                    return widget.catalog.keys.where((option) => option.toLowerCase().contains(textValue.text.toLowerCase()));
                  },
                  onSelected: (selection) {
                    prodNameCtrl.text = selection;
                    if (widget.catalog.containsKey(selection)) {
                      priceCtrl.text = widget.catalog[selection].toString();
                    }
                  },
                  fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(labelText: 'პროდუქტის დასახელება'),
                      onChanged: (val) => prodNameCtrl.text = val,
                    );
                  },
                ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'ფასი (₾)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'რაოდენობა'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    if (prodNameCtrl.text.isNotEmpty && priceCtrl.text.isNotEmpty) {
                      setDlgState(() {
                        orderItems.add(ProductItem(
                          name: prodNameCtrl.text,
                          price: double.tryParse(priceCtrl.text) ?? 0.0,
                          quantity: int.tryParse(qtyCtrl.text) ?? 1,
                        ));
                        prodNameCtrl.clear();
                        priceCtrl.clear();
                        qtyCtrl.text = '1';
                      });
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('სიას დამატება'),
                ),
                const Divider(),
                SizedBox(
                  height: 150,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: orderItems.length,
                    itemBuilder: (c, idx) => ListTile(
                      dense: true,
                      title: Text(orderItems[idx].name),
                      subtitle: Text('${orderItems[idx].quantity}x - ${orderItems[idx].price}₾'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => setDlgState(() => orderItems.removeAt(idx)),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('გაუქმება')),
            ElevatedButton(
              onPressed: () {
                if (orderItems.isNotEmpty) {
                  _addOrder(orderItems);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('შეკვეთის შენახვა'),
            ),
          ],
        ),
      ),
    );
  }
}
