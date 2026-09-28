import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class SearchProductsScreen extends StatefulWidget {
  const SearchProductsScreen({super.key});

  @override
  State<SearchProductsScreen> createState() => _SearchProductsScreenState();
}

class _SearchProductsScreenState extends State<SearchProductsScreen> {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const warning = Color(0xFFE8A44A);
  static const success = Color(0xFF4CAF82);

  final _controller = TextEditingController();
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _results = [];
  List<String> _recentSearches = ['box1', 'șuruburi', 'product_box1'];

  bool _loading = true;
  bool _hasSearched = false;
  Map<String, dynamic>? _selectedProduct;

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
    _loadFromFirebase();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadFromFirebase() async {
    setState(() => _loading = true);

    try {
      final snapshot = await _db.get();

      if (!snapshot.exists || snapshot.value == null) {
        setState(() {
          _products = [];
          _results = [];
        });
        return;
      }

      final root = Map<String, dynamic>.from(snapshot.value as Map);
      final parsed = _parseProducts(root);

      setState(() {
        _products = parsed;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
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

      final quantity = _toInt(box['quantity']);
      final maxStock = _toInt(product['maxStock']);
      final redThreshold = _toInt(product['redThreshold']);
      final yellowThreshold = _toInt(product['yellowThreshold']);

      result.add({
        'productId': productId,
        'code': productId,
        'name': product['name']?.toString() ?? 'Produs fără nume',
        'unit': product['unit']?.toString() ?? 'buc',
        'boxId': boxId,
        'boxName': box['name']?.toString() ?? boxId,
        'quantity': quantity,
        'maxStock': maxStock,
        'redThreshold': redThreshold,
        'yellowThreshold': yellowThreshold,
        'lastWeightRaw': _toInt(box['lastWeightRaw']),
        'lastUpdate': _toInt(box['lastUpdate']),
        'initialized': box['initialized'] == true,
      });
    }

    result.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    return result;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  void _search(String q) {
    final query = q.trim();
    if (query.isEmpty) return;

    if (!_recentSearches.contains(query)) {
      _recentSearches = [query, ..._recentSearches.take(4).toList()];
    }

    final lower = query.toLowerCase();

    final found = _products.where((p) {
      final name = p['name'].toString().toLowerCase();
      final code = p['code'].toString().toLowerCase();
      final boxId = p['boxId'].toString().toLowerCase();
      final boxName = p['boxName'].toString().toLowerCase();

      return name.contains(lower) ||
          code.contains(lower) ||
          boxId.contains(lower) ||
          boxName.contains(lower);
    }).toList();

    setState(() {
      _hasSearched = true;
      _selectedProduct = null;
      _results = found;
    });
  }

  Color _stockColor(Map<String, dynamic> p) {
    final qty = _toInt(p['quantity']);
    final red = _toInt(p['redThreshold']);
    final yellow = _toInt(p['yellowThreshold']);

    if (qty <= red) return danger;
    if (qty <= yellow) return warning;
    return success;
  }

  String _stockLabel(Map<String, dynamic> p) {
    final qty = _toInt(p['quantity']);
    final red = _toInt(p['redThreshold']);
    final yellow = _toInt(p['yellowThreshold']);

    if (qty <= red) return 'Critic';
    if (qty <= yellow) return 'Stoc scăzut';
    return 'În stoc';
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _hasSearched = false;
      _results = [];
      _selectedProduct = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(
                child: CircularProgressIndicator(color: teal),
              )
                  : _selectedProduct != null
                  ? _buildProductDetail(_selectedProduct!)
                  : !_hasSearched
                  ? _buildSuggestions()
                  : _results.isEmpty
                  ? _buildNoResults()
                  : _buildResults(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _selectedProduct != null
                ? () => setState(() => _selectedProduct = null)
                : () => Navigator.pop(context),
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
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: TextField(
                controller: _controller,
                autofocus: !_hasSearched,
                onSubmitted: _search,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: 'Cod produs, cutie sau denumire...',
                  hintStyle: TextStyle(
                    color: mutedColor,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: teal,
                    size: 20,
                  ),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(
                      Icons.clear_rounded,
                      color: teal,
                      size: 18,
                    ),
                    onPressed: _clearSearch,
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _search(_controller.text),
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: midBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    final suggestions = [
      'box1',
      'box2',
      'box3',
      'șuruburi',
      'product_box1',
      'critic',
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _sectionLabel('Căutări recente'),
        const SizedBox(height: 12),
        ..._recentSearches.map(
              (s) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(
              Icons.history_rounded,
              color: teal,
              size: 20,
            ),
            title: Text(
              s,
              style: TextStyle(
                color: textColor.withOpacity(0.85),
                fontSize: 14,
              ),
            ),
            trailing: Icon(
              Icons.north_west_rounded,
              color: mutedColor,
              size: 16,
            ),
            onTap: () {
              _controller.text = s;
              _search(s);
            },
          ),
        ),
        const SizedBox(height: 24),
        _sectionLabel('Sugestii'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((tag) {
            return GestureDetector(
              onTap: () {
                _controller.text = tag;
                _search(tag);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    color: teal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        Text(
          '${_products.length} produse disponibile în Firebase',
          style: TextStyle(
            color: mutedColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: mutedColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                '${_results.length} rezultate pentru "${_controller.text}"',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _results.length,
            itemBuilder: (_, i) {
              final p = _results[i];
              final qty = _toInt(p['quantity']);
              final col = _stockColor(p);

              return GestureDetector(
                onTap: () => setState(() => _selectedProduct = p),
                child: Container(
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
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: col,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: col.withOpacity(0.45),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['name'].toString(),
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    p['code'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.inventory_2_rounded,
                                  color: teal,
                                  size: 11,
                                ),
                                const SizedBox(width: 2),
                                Flexible(
                                  child: Text(
                                    p['boxId'].toString(),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$qty ${p['unit']}',
                            style: TextStyle(
                              color: col,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            _stockLabel(p),
                            style: TextStyle(
                              color: col.withOpacity(0.75),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: teal,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductDetail(Map<String, dynamic> p) {
    final qty = _toInt(p['quantity']);
    final maxStock = _toInt(p['maxStock']);
    final red = _toInt(p['redThreshold']);
    final yellow = _toInt(p['yellowThreshold']);
    final col = _stockColor(p);
    final progress = maxStock == 0 ? 0.0 : qty / maxStock;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: col.withOpacity(0.30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _statusBadge(_stockLabel(p), col),
                    const Spacer(),
                    Text(
                      p['code'].toString(),
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  p['name'].toString(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _detailStat('$qty', '${p['unit']} în stoc', col),
                    const SizedBox(width: 20),
                    _detailStat('$maxStock', 'max stock', teal),
                    const SizedBox(width: 20),
                    _detailStat('$yellow', 'prag galben', warning),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: isDark
                        ? Colors.white.withOpacity(0.08)
                        : darkBlue.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(col),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _infoCard(Icons.inventory_2_rounded, 'Cutie', p['boxName'].toString()),
          const SizedBox(height: 10),
          _infoCard(Icons.qr_code_rounded, 'Box ID', p['boxId'].toString()),
          const SizedBox(height: 10),
          _infoCard(Icons.dangerous_rounded, 'Prag roșu', '$red ${p['unit']}'),
          const SizedBox(height: 10),
          _infoCard(
            Icons.scale_rounded,
            'Ultima citire raw',
            p['lastWeightRaw'].toString(),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/create-order',
                      arguments: {
                        'prefill': [p],
                      },
                    );
                  },
                  icon: const Icon(
                    Icons.add_shopping_cart_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'Comandă',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: midBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/qr-scan'),
                  icon: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 18,
                    color: teal,
                  ),
                  label: const Text(
                    'Scan cutie',
                    style: TextStyle(
                      color: teal,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: teal),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
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

  Widget _detailStat(String value, String label, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mutedColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: teal, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              color: mutedColor,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              'Niciun rezultat',
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nu s-a găsit nimic pentru "${_controller.text}"',
              textAlign: TextAlign.center,
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
}