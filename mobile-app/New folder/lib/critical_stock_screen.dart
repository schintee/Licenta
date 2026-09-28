import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CriticalStockScreen extends StatefulWidget {
  const CriticalStockScreen({super.key});

  @override
  State<CriticalStockScreen> createState() => _CriticalStockScreenState();
}

class _CriticalStockScreenState extends State<CriticalStockScreen> {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const warning = Color(0xFFE8A44A);
  static const success = Color(0xFF4CAF82);

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String _sortBy = 'quantity';
  String _searchQuery = '';

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _filtered = [];

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: StreamBuilder(
                stream: _db.onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: teal),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data?.snapshot.value == null) {
                    return _buildEmptyDatabase();
                  }

                  final root = Map<String, dynamic>.from(
                    snapshot.data!.snapshot.value as Map,
                  );

                  _allProducts = _parseCriticalProducts(root);
                  _applyFilter();

                  return Column(
                    children: [
                      _buildStats(),
                      _buildSearchSort(),
                      Expanded(
                        child: _filtered.isEmpty
                            ? _buildEmpty()
                            : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _buildCard(_filtered[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _allProducts.isNotEmpty
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(
            context,
            '/create-order',
            arguments: {'prefill': _allProducts},
          );
        },
        backgroundColor: midBlue,
        icon: const Icon(
          Icons.add_shopping_cart_rounded,
          color: Colors.white,
        ),
        label: const Text(
          'Comandă tot',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      )
          : null,
    );
  }

  List<Map<String, dynamic>> _parseCriticalProducts(Map<String, dynamic> root) {
    final boxesRaw = root['boxes'];
    final productsRaw = root['products'];

    if (boxesRaw == null || productsRaw == null) return [];

    final boxes = Map<String, dynamic>.from(boxesRaw as Map);
    final products = Map<String, dynamic>.from(productsRaw as Map);

    final result = <Map<String, dynamic>>[];

    for (final productEntry in products.entries) {
      final productId = productEntry.key;
      final product = Map<String, dynamic>.from(productEntry.value as Map);

      if (product['active'] == false) continue;

      final boxId = product['boxId']?.toString() ?? '';
      if (boxId.isEmpty || !boxes.containsKey(boxId)) continue;

      final box = Map<String, dynamic>.from(boxes[boxId] as Map);

      final quantity = _toInt(box['quantity']);
      final redThreshold = _toInt(product['redThreshold']);
      final yellowThreshold = _toInt(product['yellowThreshold']);
      final maxStock = _toInt(product['maxStock']);

      final isCritical = quantity <= redThreshold;
      final isLow = quantity <= yellowThreshold;

      if (!isLow) continue;

      result.add({
        'productId': productId,
        'boxId': boxId,
        'code': productId,
        'name': product['name']?.toString() ?? 'Produs fără nume',
        'unit': product['unit']?.toString() ?? 'buc',
        'quantity': quantity,
        'maxStock': maxStock,
        'yellowThreshold': yellowThreshold,
        'redThreshold': redThreshold,
        'deficit': (maxStock - quantity).clamp(0, 999999),
        'location': box['name']?.toString() ?? boxId,
        'status': isCritical ? 'CRITIC' : 'SCĂZUT',
        'color': isCritical ? danger : warning,
      });
    }

    return result;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  void _applyFilter() {
    var list = List<Map<String, dynamic>>.from(_allProducts);

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();

      list = list.where((p) {
        final name = p['name'].toString().toLowerCase();
        final code = p['code'].toString().toLowerCase();
        final boxId = p['boxId'].toString().toLowerCase();

        return name.contains(q) || code.contains(q) || boxId.contains(q);
      }).toList();
    }

    list.sort((a, b) {
      switch (_sortBy) {
        case 'name':
          return a['name'].toString().compareTo(b['name'].toString());

        case 'deficit':
          return _toInt(b['deficit']).compareTo(_toInt(a['deficit']));

        case 'status':
          return a['status'].toString().compareTo(b['status'].toString());

        default:
          return _toInt(a['quantity']).compareTo(_toInt(b['quantity']));
      }
    });

    _filtered = list;
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
                  'Stoc Critic',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Produse ce necesită comandă',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.sync_rounded,
            color: teal,
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final critic = _allProducts.where((p) => p['status'] == 'CRITIC').length;
    final scazut = _allProducts.where((p) => p['status'] == 'SCĂZUT').length;
    final deficit = _allProducts.fold<int>(
      0,
          (sum, p) => sum + _toInt(p['deficit']),
    );

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          _statChip('${_allProducts.length}', 'Total', teal),
          _divider(),
          _statChip('$critic', 'Critic', danger),
          _divider(),
          _statChip('$scazut', 'Scăzut', warning),
          _divider(),
          _statChip('$deficit', 'Deficit', textColor),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: mutedColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 32,
      color: border,
    );
  }

  Widget _buildSearchSort() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: TextField(
                onChanged: (v) {
                  setState(() {
                    _searchQuery = v;
                    _applyFilter();
                  });
                },
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: 'Caută produs...',
                  hintStyle: TextStyle(
                    color: mutedColor,
                    fontSize: 13,
                  ),
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
          const SizedBox(width: 10),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _sortBy,
                dropdownColor: cardBg,
                style: const TextStyle(
                  color: teal,
                  fontSize: 12,
                ),
                icon: const Icon(
                  Icons.sort_rounded,
                  color: teal,
                  size: 16,
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'quantity',
                    child: Text('Cantitate'),
                  ),
                  DropdownMenuItem(
                    value: 'deficit',
                    child: Text('Deficit'),
                  ),
                  DropdownMenuItem(
                    value: 'status',
                    child: Text('Status'),
                  ),
                  DropdownMenuItem(
                    value: 'name',
                    child: Text('Nume'),
                  ),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    _sortBy = v;
                    _applyFilter();
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> p) {
    final qty = _toInt(p['quantity']);
    final maxStock = _toInt(p['maxStock']);
    final deficit = _toInt(p['deficit']);
    final color = p['color'] as Color;
    final progress = maxStock == 0 ? 0.0 : qty / maxStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(height: 3, color: color),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p['name'].toString(),
                            style: TextStyle(
                              color: textColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${p['boxId']} · ${p['code']}',
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    _statusBadge(p['status'].toString(), color),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '$qty',
                      style: TextStyle(
                        color: color,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      ' / $maxStock ${p['unit']}',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Deficit: $deficit ${p['unit']}',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : darkBlue.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_rounded,
                      color: teal,
                      size: 15,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        p['location'].toString(),
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          '/create-order',
                          arguments: {
                            'prefill': [p],
                          },
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: midBlue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Comandă',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.4),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyDatabase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          'Nu există date în Firebase încă.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: mutedColor,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
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
                color: success.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: success,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stoc în regulă!',
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Niciun produs sub pragul galben.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: mutedColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}