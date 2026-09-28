import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const warning = Color(0xFFE8A44A);
  static const success = Color(0xFF4CAF82);

  final DatabaseReference _db = FirebaseDatabase.instance.ref();
  final _notesController = TextEditingController();

  final List<_OrderItem> _items = [];

  bool _submitting = false;
  bool _submitted = false;
  bool _loadingProducts = true;
  bool _didReadArgs = false;

  String? _orderId;

  List<Map<String, dynamic>> _allProducts = [];

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bg => isDark ? darkBlue : light;
  Color get cardBg => isDark ? const Color(0xFF0F3244) : Colors.white;
  Color get headerBg => isDark ? const Color(0xFF08263A) : Colors.white;
  Color get textColor => isDark ? light : darkBlue;
  Color get mutedColor =>
      isDark ? light.withOpacity(0.55) : darkBlue.withOpacity(0.48);
  Color get border =>
      isDark ? teal.withOpacity(0.20) : midBlue.withOpacity(0.13);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didReadArgs) return;
    _didReadArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map<String, dynamic>) {
      final prefill = args['prefill'];

      if (prefill is List) {
        for (final raw in prefill) {
          if (raw is Map) {
            _addPrefillItem(Map<String, dynamic>.from(raw));
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _loadingProducts = true);

    try {
      final snapshot = await _db.get();

      if (!snapshot.exists || snapshot.value == null) {
        setState(() => _allProducts = []);
        return;
      }

      final root = Map<String, dynamic>.from(snapshot.value as Map);
      final parsed = _parseProducts(root);

      setState(() => _allProducts = parsed);
    } finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  List<Map<String, dynamic>> _parseProducts(Map<String, dynamic> root) {
    final productsRaw = root['products'];
    final boxesRaw = root['boxes'];

    if (productsRaw == null || boxesRaw == null) return [];

    final products = Map<String, dynamic>.from(productsRaw as Map);
    final boxes = Map<String, dynamic>.from(boxesRaw as Map);

    final result = <Map<String, dynamic>>[];

    for (final entry in products.entries) {
      final productId = entry.key;
      final product = Map<String, dynamic>.from(entry.value as Map);

      if (product['active'] == false) continue;

      final boxId = product['boxId']?.toString() ?? '';
      final box = boxes[boxId] == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(boxes[boxId] as Map);

      result.add({
        'productId': productId,
        'code': productId,
        'name': product['name']?.toString() ?? 'Produs fără nume',
        'unit': product['unit']?.toString() ?? 'buc',
        'boxId': boxId,
        'boxName': box['name']?.toString() ?? boxId,
        'quantity': _toInt(box['quantity']),
        'maxStock': _toInt(product['maxStock']),
        'yellowThreshold': _toInt(product['yellowThreshold']),
        'redThreshold': _toInt(product['redThreshold']),
      });
    }

    result.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    return result;
  }

  void _addPrefillItem(Map<String, dynamic> product) {
    final maxStock = _toInt(product['maxStock'] ?? product['max_stock']);
    final qty = _toInt(product['quantity']);
    final deficit = _toInt(product['deficit']);

    final needed = deficit > 0
        ? deficit
        : maxStock > qty
        ? maxStock - qty
        : 1;

    _addItemFromProduct(product, initialQuantity: needed);
  }

  void _addProduct(Map<String, dynamic> product) {
    _addItemFromProduct(product, initialQuantity: 1);
    Navigator.pop(context);
  }

  void _addItemFromProduct(
      Map<String, dynamic> product, {
        required int initialQuantity,
      }) {
    final productId =
        '${product['productId'] ?? product['id'] ?? product['code'] ?? ''}';

    final code = '${product['code'] ?? productId}';
    final boxId = '${product['boxId'] ?? ''}';

    if (productId.trim().isEmpty && code.trim().isEmpty) return;

    final existing = _items.indexWhere(
          (i) => i.productId == productId || i.productCode == code,
    );

    if (existing >= 0) {
      setState(() {
        _items[existing].quantity += initialQuantity.clamp(1, 99999);
      });
    } else {
      setState(() {
        _items.add(
          _OrderItem(
            productId: productId.isEmpty ? code : productId,
            productName: '${product['name'] ?? 'Produs'}',
            productCode: code,
            boxId: boxId,
            unit: '${product['unit'] ?? 'buc'}',
            quantity: initialQuantity.clamp(1, 99999),
          ),
        );
      });
    }
  }

  Future<void> _submit() async {
    if (_items.isEmpty || _submitting) return;

    setState(() => _submitting = true);

    try {
      final ref = _db.child('orders').push();
      final id = ref.key ?? DateTime.now().millisecondsSinceEpoch.toString();

      await ref.set({
        'status': 'new',
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
        'createdBy': 'Utilizator',
        'notes': _notesController.text.trim(),
        'items': _items.map((i) {
          return {
            'productId': i.productId,
            'productName': i.productName,
            'name': i.productName,
            'productCode': i.productCode,
            'boxId': i.boxId,
            'quantity': i.quantity,
            'unit': i.unit,
          };
        }).toList(),
      });

      setState(() {
        _orderId = id;
        _submitted = true;
      });
    } catch (_) {
      _showMessage('Eroare la trimiterea comenzii.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  int get _totalItems => _items.fold(0, (s, i) => s + i.quantity);

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: headerBg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccessScreen();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _items.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._items
                      .asMap()
                      .entries
                      .map((e) => _buildItemCard(e.key, e.value)),
                  const SizedBox(height: 8),
                  _buildNotesField(),
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _showProductPicker,
            backgroundColor: cardBg,
            child: const Icon(
              Icons.add_rounded,
              color: teal,
            ),
          ),
          const SizedBox(height: 10),
          if (_items.isNotEmpty)
            FloatingActionButton.extended(
              heroTag: 'submit',
              onPressed: _submitting ? null : _submit,
              backgroundColor: midBlue,
              icon: _submitting
                  ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.send_rounded,
                color: Colors.white,
              ),
              label: Text(
                'Trimite ($_totalItems produse)',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: textColor,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creează Comandă',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Adaugă produse și trimite',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_items.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _items.clear()),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Șterge tot',
                  style: TextStyle(
                    color: danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, _OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: midBlue.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: teal,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.boxId.isEmpty
                      ? item.productCode
                      : '${item.productCode} · ${item.boxId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                _qtyBtn(Icons.remove_rounded, () {
                  if (item.quantity > 1) {
                    setState(() => item.quantity--);
                  } else {
                    setState(() => _items.removeAt(index));
                  }
                }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    '${item.quantity}',
                    style: TextStyle(
                      color: textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _qtyBtn(
                  Icons.add_rounded,
                      () => setState(() => item.quantity++),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.unit,
            style: TextStyle(
              color: mutedColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: midBlue.withOpacity(0.22),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: teal,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 3,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Note comandă (opțional)...',
          hintStyle: TextStyle(color: mutedColor),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 14, right: 8, top: 14),
            child: Icon(
              Icons.notes_rounded,
              color: teal,
              size: 20,
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: midBlue.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: teal,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Comanda e goală',
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Apasă + pentru a adăuga produse',
              style: TextStyle(
                color: mutedColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF0A2838) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => _ProductPickerSheet(
        products: _allProducts,
        loading: _loadingProducts,
        onSelect: _addProduct,
        isDark: isDark,
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: success.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: success.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: success,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Comandă trimisă!',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Comanda #$_orderId a fost înregistrată cu succes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                      context,
                      '/previous-orders',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: midBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Vezi comenzile',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Înapoi la Home',
                    style: TextStyle(color: teal),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderItem {
  final String productId;
  final String productName;
  final String productCode;
  final String boxId;
  final String unit;
  int quantity;

  _OrderItem({
    required this.productId,
    required this.productName,
    required this.productCode,
    required this.boxId,
    required this.unit,
    required this.quantity,
  });
}

class _ProductPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final bool loading;
  final bool isDark;
  final Function(Map<String, dynamic>) onSelect;

  const _ProductPickerSheet({
    required this.products,
    required this.loading,
    required this.isDark,
    required this.onSelect,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const warning = Color(0xFFE8A44A);

  String _q = '';

  Color get bg => widget.isDark ? darkBlue : light;
  Color get cardBg => widget.isDark ? const Color(0xFF0F3244) : Colors.white;
  Color get textColor => widget.isDark ? light : darkBlue;
  Color get mutedColor =>
      widget.isDark ? light.withOpacity(0.55) : darkBlue.withOpacity(0.48);
  Color get border =>
      widget.isDark ? teal.withOpacity(0.20) : midBlue.withOpacity(0.13);

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products.where((p) {
      final name = '${p['name'] ?? ''}'.toLowerCase();
      final code = '${p['code'] ?? ''}'.toLowerCase();
      final boxId = '${p['boxId'] ?? ''}'.toLowerCase();
      final q = _q.toLowerCase();

      return name.contains(q) || code.contains(q) || boxId.contains(q);
    }).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) {
        return Container(
          color: widget.isDark ? const Color(0xFF0A2838) : Colors.white,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Selectează produs',
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: border),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _q = v),
                    autofocus: true,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Caută produs sau cutie...',
                      hintStyle: TextStyle(color: mutedColor),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: teal,
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: widget.loading
                    ? const Center(
                  child: CircularProgressIndicator(color: teal),
                )
                    : filtered.isEmpty
                    ? Center(
                  child: Text(
                    'Nu există produse configurate încă.',
                    style: TextStyle(color: mutedColor),
                  ),
                )
                    : ListView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final qty = _toInt(p['quantity']);
                    final yellow = _toInt(p['yellowThreshold']);
                    final isLow = qty <= yellow;

                    return ListTile(
                      onTap: () => widget.onSelect(p),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: midBlue.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_rounded,
                          color: teal,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        '${p['name'] ?? 'Produs'}',
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${p['code']} · ${p['boxId']} · Stoc: $qty ${p['unit']}',
                        style: TextStyle(
                          color: isLow ? warning : mutedColor,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Icon(
                        isLow
                            ? Icons.warning_amber_rounded
                            : Icons.add_circle_outline_rounded,
                        color: isLow ? warning : teal,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }
}