import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PreviousOrdersScreen extends StatefulWidget {
  const PreviousOrdersScreen({super.key});

  @override
  State<PreviousOrdersScreen> createState() => _PreviousOrdersScreenState();
}

class _PreviousOrdersScreenState extends State<PreviousOrdersScreen> {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const warning = Color(0xFFE8A44A);
  static const success = Color(0xFF4CAF82);
  static const processingBlue = Color(0xFF4DA3FF);

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _filtered = [];

  String _filterStatus = 'all';
  String _searchQuery = '';

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bg => isDark ? darkBlue : light;
  Color get cardBg => isDark ? const Color(0xFF0F3244) : Colors.white;
  Color get headerBg => isDark ? const Color(0xFF08263A) : Colors.white;
  Color get textColor => isDark ? light : darkBlue;
  Color get mutedColor =>
      isDark ? light.withOpacity(0.55) : darkBlue.withOpacity(0.48);
  Color get border =>
      isDark ? teal.withOpacity(0.20) : midBlue.withOpacity(0.13);

  void _parseOrders(dynamic value) {
    if (value == null) {
      _orders = [];
      _filtered = [];
      return;
    }

    final raw = Map<String, dynamic>.from(value as Map);
    final list = <Map<String, dynamic>>[];

    for (final entry in raw.entries) {
      final orderId = entry.key;
      final order = Map<String, dynamic>.from(entry.value as Map);

      list.add({
        'id': orderId,
        'status': order['status']?.toString() ?? 'new',
        'notes': order['notes']?.toString() ?? '',
        'createdAt': _toInt(order['createdAt'] ?? order['created_at']),
        'createdBy': order['createdBy']?.toString() ?? 'Angajat',
        'items': _parseItems(order['items'] ?? order['order_items']),
      });
    }

    list.sort((a, b) => _toInt(b['createdAt']).compareTo(_toInt(a['createdAt'])));

    _orders = list;
    _applyFilter();
  }

  List<Map<String, dynamic>> _parseItems(dynamic rawItems) {
    if (rawItems == null) return [];

    if (rawItems is List) {
      return rawItems.where((e) => e != null).map((e) {
        return Map<String, dynamic>.from(e as Map);
      }).toList();
    }

    if (rawItems is Map) {
      final map = Map<String, dynamic>.from(rawItems);
      return map.entries.map((e) {
        final item = Map<String, dynamic>.from(e.value as Map);
        item['id'] = e.key;
        return item;
      }).toList();
    }

    return [];
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse(value.toString()) ?? 0;
  }

  void _applyFilter() {
    var list = List<Map<String, dynamic>>.from(_orders);

    if (_filterStatus != 'all') {
      list = list.where((o) => o['status'] == _filterStatus).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();

      list = list.where((o) {
        final id = o['id'].toString().toLowerCase();
        final user = o['createdBy'].toString().toLowerCase();
        final items = o['items'] as List;

        final productMatch = items.any((item) {
          final m = Map<String, dynamic>.from(item as Map);
          final name = m['name']?.toString().toLowerCase() ?? '';
          final code = m['productId']?.toString().toLowerCase() ?? '';
          final boxId = m['boxId']?.toString().toLowerCase() ?? '';
          return name.contains(q) || code.contains(q) || boxId.contains(q);
        });

        return id.contains(q) || user.contains(q) || productMatch;
      }).toList();
    }

    _filtered = list;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'new':
        return warning;
      case 'processing':
        return processingBlue;
      case 'completed':
        return success;
      default:
        return warning;
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'new':
        return 'Comandă nouă';
      case 'processing':
        return 'În curs';
      case 'completed':
        return 'Finalizată';
      default:
        return 'Comandă nouă';
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'new':
        return Icons.fiber_new_rounded;
      case 'processing':
        return Icons.sync_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.fiber_new_rounded;
    }
  }

  String _formatDate(int millis) {
    if (millis == 0) return '-';

    final dt = DateTime.fromMillisecondsSinceEpoch(millis);

    return '${dt.day.toString().padLeft(2, '0')}.'
        '${dt.month.toString().padLeft(2, '0')}.'
        '${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _updateStatus(Map<String, dynamic> order, String status) async {
    final id = order['id'].toString();

    await _db.child('orders/$id').update({
      'status': status,
      'updatedAt': ServerValue.timestamp,
    });

    _showMessage(
      status == 'processing'
          ? 'Comanda a fost preluată.'
          : 'Comanda a fost finalizată.',
    );
  }

  Future<void> _deleteOrder(Map<String, dynamic> order) async {
    final id = order['id'].toString();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBg,
        title: Text(
          'Ștergere comandă',
          style: TextStyle(color: textColor),
        ),
        content: Text(
          'Sigur vrei să ștergi comanda #$id?',
          style: TextStyle(color: mutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nu'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Da'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _db.child('orders/$id').remove();
    _showMessage('Comanda a fost ștearsă.');
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
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterBar(),
            _buildSearchBar(),
            Expanded(
              child: StreamBuilder(
                stream: _db.child('orders').onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: teal),
                    );
                  }

                  _parseOrders(snapshot.data?.snapshot.value);

                  if (_filtered.isEmpty) return _buildEmpty();

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _buildOrderCard(_filtered[i]),
                  );
                },
              ),
            ),
          ],
        ),
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
                  'Comenzi',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_orders.length} comenzi înregistrate',
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

  Widget _buildFilterBar() {
    const filters = [
      ('all', 'Toate'),
      ('new', 'Noi'),
      ('processing', 'În curs'),
      ('completed', 'Finalizate'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.map((f) {
          final active = _filterStatus == f.$1;

          return GestureDetector(
            onTap: () {
              setState(() {
                _filterStatus = f.$1;
                _applyFilter();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? midBlue : cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? teal : border,
                ),
              ),
              child: Text(
                f.$2,
                style: TextStyle(
                  color: active ? Colors.white : mutedColor,
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(10),
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
            hintText: 'Caută după produs, cutie sau #comandă...',
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
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'].toString();
    final color = _statusColor(status);
    final items = order['items'] as List;
    final date = _formatDate(_toInt(order['createdAt']));
    final employee = order['createdBy'].toString();
    final orderId = order['id'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: teal,
          collapsedIconColor: teal,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _statusIcon(status),
              color: color,
              size: 22,
            ),
          ),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  '#$orderId',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(_statusLabel(status), color),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _smallInfo(Icons.person_rounded, employee),
                const SizedBox(height: 2),
                _smallInfo(Icons.access_time_rounded, date),
              ],
            ),
          ),
          children: [
            Divider(color: border),
            ...items.map((rawItem) {
              final item = Map<String, dynamic>.from(rawItem as Map);

              final name = item['name']?.toString() ??
                  item['productName']?.toString() ??
                  'Produs';
              final productId = item['productId']?.toString() ?? '-';
              final boxId = item['boxId']?.toString() ?? '-';
              final quantity = _toInt(item['quantity']);
              final unit = item['unit']?.toString() ?? 'buc';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.circle, color: teal, size: 6),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: textColor.withOpacity(0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$productId · $boxId',
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$quantity $unit',
                      style: const TextStyle(
                        color: teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (order['notes'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.notes_rounded,
                      color: teal,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        order['notes'].toString(),
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            _buildActionButtons(order),
          ],
        ),
      ),
    );
  }

  Widget _smallInfo(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: teal, size: 13),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: mutedColor,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> order) {
    final status = order['status'].toString();

    return Row(
      children: [
        if (status == 'new')
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(order, 'processing'),
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Preluare'),
              style: ElevatedButton.styleFrom(
                backgroundColor: midBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        if (status == 'processing')
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateStatus(order, 'completed'),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Finalizează'),
              style: ElevatedButton.styleFrom(
                backgroundColor: success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        if (status != 'completed') const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _deleteOrder(order),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Ștergere'),
            style: OutlinedButton.styleFrom(
              foregroundColor: danger,
              side: const BorderSide(color: danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
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
                color: midBlue.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: teal,
                size: 38,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nicio comandă',
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Nu există comenzi în această categorie.',
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