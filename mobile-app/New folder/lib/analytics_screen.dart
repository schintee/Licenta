import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const warning = Color(0xFFE8A44A);
  static const success = Color(0xFF4CAF82);
  static const processingBlue = Color(0xFF4DA3FF);

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  late TabController _tab;

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
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  bool _isToday(int timestamp) {
    if (timestamp <= 0) return false;

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    return _dateKey(date) == _dateKey(now);
  }

  int _daysAgoIndex(int timestamp) {
    if (timestamp <= 0) return -1;

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final orderDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(orderDay).inDays;

    if (diff < 0 || diff > 6) return -1;

    return 6 - diff;
  }

  int _statusPriority(String status) {
    switch (status) {
      case 'Critic':
        return 0;
      case 'Scăzut':
        return 1;
      default:
        return 2;
    }
  }

  Map<String, dynamic> _buildAnalytics(dynamic value) {
    if (value == null || value is! Map) {
      return _emptyAnalytics();
    }

    final root = Map<String, dynamic>.from(value);

    final boxes = _safeMap(root['boxes']);
    final products = _safeMap(root['products']);
    final orders = _safeMap(root['orders']);

    int totalProducts = 0;
    int totalBoxes = boxes.length;
    int critical = 0;
    int low = 0;
    int ok = 0;
    int totalStock = 0;
    int totalMaxStock = 0;

    final productRows = <Map<String, dynamic>>[];

    for (final entry in products.entries) {
      final productId = entry.key.toString();
      final product = _safeMap(entry.value);

      if (product['active'] == false) continue;

      totalProducts++;

      final boxId = product['boxId']?.toString() ?? '';
      final box = _safeMap(boxes[boxId]);

      final quantity = _toInt(box['quantity']);
      final maxStock = _toInt(product['maxStock']);
      final red = _toInt(product['redThreshold']);
      final yellow = _toInt(product['yellowThreshold']);

      totalStock += quantity;
      totalMaxStock += maxStock;

      String status;
      Color color;

      if (quantity <= red) {
        critical++;
        status = 'Critic';
        color = danger;
      } else if (quantity <= yellow) {
        low++;
        status = 'Scăzut';
        color = warning;
      } else {
        ok++;
        status = 'OK';
        color = success;
      }

      final stockPercent = maxStock <= 0
          ? 0
          : ((quantity / maxStock) * 100).clamp(0, 999).round();

      final deficit = maxStock > quantity ? maxStock - quantity : 0;

      productRows.add({
        'productId': productId,
        'name': product['name']?.toString() ?? 'Produs fără nume',
        'boxId': boxId,
        'quantity': quantity,
        'maxStock': maxStock,
        'redThreshold': red,
        'yellowThreshold': yellow,
        'unit': product['unit']?.toString() ?? 'buc',
        'status': status,
        'color': color,
        'stockPercent': stockPercent,
        'deficit': deficit,
      });
    }

    productRows.sort((a, b) {
      final s = _statusPriority(a['status'].toString())
          .compareTo(_statusPriority(b['status'].toString()));

      if (s != 0) return s;

      return _toInt(a['quantity']).compareTo(_toInt(b['quantity']));
    });

    int newOrders = 0;
    int processingOrders = 0;
    int completedOrders = 0;
    int totalOrderedQty = 0;
    int ordersToday = 0;

    final ordersByDay = List<int>.filled(7, 0);
    final topMap = <String, Map<String, dynamic>>{};

    for (final orderEntry in orders.entries) {
      final order = _safeMap(orderEntry.value);
      final status = order['status']?.toString() ?? 'new';

      if (status == 'new') newOrders++;
      if (status == 'processing') processingOrders++;
      if (status == 'completed') completedOrders++;

      final createdAt = _toInt(order['createdAt'] ?? order['created_at']);

      if (_isToday(createdAt)) {
        ordersToday++;
      }

      final dayIndex = _daysAgoIndex(createdAt);
      if (dayIndex >= 0 && dayIndex < 7) {
        ordersByDay[dayIndex]++;
      }

      final items = _parseItems(order['items'] ?? order['order_items']);

      for (final item in items) {
        final quantity = _toInt(item['quantity']);

        final productId = item['productId']?.toString() ??
            item['product_id']?.toString() ??
            item['productCode']?.toString() ??
            'produs';

        final name = item['name']?.toString() ??
            item['productName']?.toString() ??
            productId;

        totalOrderedQty += quantity;

        topMap.putIfAbsent(productId, () {
          return {
            'productId': productId,
            'name': name,
            'qty': 0,
          };
        });

        topMap[productId]!['qty'] = _toInt(topMap[productId]!['qty']) + quantity;
      }
    }

    final topProducts = topMap.values.toList()
      ..sort((a, b) => _toInt(b['qty']).compareTo(_toInt(a['qty'])));

    final occupancy = totalMaxStock == 0
        ? 0
        : ((totalStock / totalMaxStock) * 100).clamp(0, 999).round();

    final totalOrders = orders.length;
    final completionRate =
    totalOrders == 0 ? 0 : ((completedOrders / totalOrders) * 100).round();

    final healthScore = totalProducts == 0
        ? 0
        : (((ok * 100) + (low * 55) + (critical * 15)) / totalProducts).round();

    final attentionProducts = productRows.where((p) {
      final status = p['status'].toString();
      return status == 'Critic' || status == 'Scăzut';
    }).toList();

    final lowStockProducts = productRows.take(6).toList();

    return {
      'totalProducts': totalProducts,
      'totalBoxes': totalBoxes,
      'critical': critical,
      'low': low,
      'ok': ok,
      'totalStock': totalStock,
      'totalMaxStock': totalMaxStock,
      'occupancy': occupancy,
      'newOrders': newOrders,
      'processingOrders': processingOrders,
      'completedOrders': completedOrders,
      'totalOrders': totalOrders,
      'totalOrderedQty': totalOrderedQty,
      'ordersToday': ordersToday,
      'completionRate': completionRate,
      'healthScore': healthScore,
      'productRows': productRows,
      'attentionProducts': attentionProducts.take(5).toList(),
      'lowStockProducts': lowStockProducts,
      'topProducts': topProducts.take(5).toList(),
      'ordersByDay': ordersByDay,
    };
  }

  List<Map<String, dynamic>> _parseItems(dynamic rawItems) {
    if (rawItems == null) return [];

    if (rawItems is List) {
      return rawItems
          .where((e) => e != null && e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    if (rawItems is Map) {
      final map = Map<String, dynamic>.from(rawItems);

      return map.values
          .where((e) => e != null && e is Map)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    return [];
  }

  Map<String, dynamic> _emptyAnalytics() {
    return {
      'totalProducts': 0,
      'totalBoxes': 0,
      'critical': 0,
      'low': 0,
      'ok': 0,
      'totalStock': 0,
      'totalMaxStock': 0,
      'occupancy': 0,
      'newOrders': 0,
      'processingOrders': 0,
      'completedOrders': 0,
      'totalOrders': 0,
      'totalOrderedQty': 0,
      'ordersToday': 0,
      'completionRate': 0,
      'healthScore': 0,
      'productRows': <Map<String, dynamic>>[],
      'attentionProducts': <Map<String, dynamic>>[],
      'lowStockProducts': <Map<String, dynamic>>[],
      'topProducts': <Map<String, dynamic>>[],
      'ordersByDay': List<int>.filled(7, 0),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: StreamBuilder(
          stream: _db.onValue,
          builder: (context, snapshot) {
            final data = _buildAnalytics(snapshot.data?.snapshot.value);

            return Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: Column(
                    children: [
                      _buildDashboardTop(data),
                      _buildTabBar(),
                      Expanded(
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            _buildGeneralTab(data),
                            _buildOrdersTab(data),
                            _buildStockTab(data),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
                  'Analytics',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Dashboard realtime pentru depozit',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: teal.withOpacity(0.25)),
            ),
            child: const Row(
              children: [
                Icon(Icons.bolt_rounded, color: teal, size: 15),
                SizedBox(width: 6),
                Text(
                  'Live',
                  style: TextStyle(
                    color: teal,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTop(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        children: [
          _buildHealthCard(data),
          const SizedBox(height: 12),
          _buildMetricScroller(data),
          const SizedBox(height: 12),
          _buildInsightStrip(data),
        ],
      ),
    );
  }

  Widget _buildHealthCard(Map<String, dynamic> data) {
    final healthScore = _toInt(data['healthScore']);
    final critical = _toInt(data['critical']);
    final low = _toInt(data['low']);
    final attention = critical + low;

    final healthColor = critical > 0
        ? danger
        : low > 0
        ? warning
        : success;

    String title;
    String subtitle;

    if (critical > 0) {
      title = 'Depozit cu risc ridicat';
      subtitle = '$critical produse critice necesită atenție imediată.';
    } else if (low > 0) {
      title = 'Depozit stabil, dar cu atenționări';
      subtitle = '$low produse sunt aproape de pragul scăzut.';
    } else if (_toInt(data['totalProducts']) == 0) {
      title = 'Nu există date suficiente';
      subtitle = 'Configurează produse și cutii pentru analiză.';
    } else {
      title = 'Depozit sănătos';
      subtitle = 'Toate produsele sunt în limite bune de stoc.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: healthColor.withOpacity(0.24)),
        boxShadow: [
          BoxShadow(
            color: healthColor.withOpacity(isDark ? 0.10 : 0.08),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: healthColor.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              critical > 0
                  ? Icons.warning_amber_rounded
                  : Icons.health_and_safety_rounded,
              color: healthColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (healthScore / 100).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: mutedColor.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(healthColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$healthScore',
                style: TextStyle(
                  color: healthColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              Text(
                'score',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: attention > 0
                      ? warning.withOpacity(0.12)
                      : success.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  attention > 0 ? '$attention alertări' : 'OK',
                  style: TextStyle(
                    color: attention > 0 ? warning : success,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricScroller(Map<String, dynamic> data) {
    final cards = [
      {
        'label': 'Produse',
        'value': '${data['totalProducts']}',
        'sub': 'active',
        'icon': Icons.inventory_2_rounded,
        'color': teal,
      },
      {
        'label': 'Cutii',
        'value': '${data['totalBoxes']}',
        'sub': 'configurate',
        'icon': Icons.inventory_rounded,
        'color': midBlue,
      },
      {
        'label': 'Comenzi azi',
        'value': '${data['ordersToday']}',
        'sub': 'astăzi',
        'icon': Icons.today_rounded,
        'color': processingBlue,
      },
      {
        'label': 'Critice',
        'value': '${data['critical']}',
        'sub': 'urgent',
        'icon': Icons.priority_high_rounded,
        'color': danger,
      },
      {
        'label': 'Ocupare',
        'value': '${data['occupancy']}%',
        'sub': 'capacitate',
        'icon': Icons.donut_large_rounded,
        'color': success,
      },
    ];

    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final c = cards[i];
          return _metricCard(
            label: c['label'] as String,
            value: c['value'] as String,
            sub: c['sub'] as String,
            icon: c['icon'] as IconData,
            color: c['color'] as Color,
          );
        },
      ),
    );
  }

  Widget _metricCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 122,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightStrip(Map<String, dynamic> data) {
    final critical = _toInt(data['critical']);
    final low = _toInt(data['low']);
    final activeOrders = _toInt(data['newOrders']) + _toInt(data['processingOrders']);

    final items = [
      {
        'title': critical > 0 ? 'Acțiune urgentă' : 'Fără urgențe',
        'value': critical > 0 ? '$critical critice' : '0 critice',
        'icon': critical > 0 ? Icons.error_rounded : Icons.verified_rounded,
        'color': critical > 0 ? danger : success,
      },
      {
        'title': 'Stoc scăzut',
        'value': '$low produse',
        'icon': Icons.trending_down_rounded,
        'color': low > 0 ? warning : success,
      },
      {
        'title': 'Comenzi active',
        'value': '$activeOrders în lucru',
        'icon': Icons.local_shipping_rounded,
        'color': activeOrders > 0 ? processingBlue : teal,
      },
    ];

    return SizedBox(
      height: 70,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final item = items[i];
          final color = item['color'] as Color;

          return Container(
            width: 180,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.22)),
            ),
            child: Row(
              children: [
                Icon(item['icon'] as IconData, color: color, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['value'] as String,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: TabBar(
        controller: _tab,
        indicator: BoxDecoration(
          color: midBlue,
          borderRadius: BorderRadius.circular(11),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: mutedColor,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'General'),
          Tab(text: 'Comenzi'),
          Tab(text: 'Stocuri'),
        ],
      ),
    );
  }

  Widget _buildGeneralTab(Map<String, dynamic> data) {
    final topProducts = List<Map<String, dynamic>>.from(data['topProducts']);
    final attentionProducts =
    List<Map<String, dynamic>>.from(data['attentionProducts']);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.auto_graph_rounded,
            title: 'Rezumat inteligent',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _miniSummary(
                  title: 'Comenzi',
                  value: '${data['totalOrders']}',
                  subtitle: '${data['completionRate']}% finalizate',
                  color: processingBlue,
                  icon: Icons.receipt_long_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _miniSummary(
                  title: 'Cantitate cerută',
                  value: '${data['totalOrderedQty']}',
                  subtitle: 'buc total comandate',
                  color: teal,
                  icon: Icons.shopping_cart_checkout_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionTitle(
            icon: Icons.local_fire_department_rounded,
            title: 'Produse care cer atenție',
          ),
          const SizedBox(height: 12),
          if (attentionProducts.isEmpty)
            _successCard('Nu există produse critice sau scăzute.')
          else
            ...attentionProducts.map((p) => _stockProductCard(p)),
          const SizedBox(height: 18),
          _sectionTitle(
            icon: Icons.emoji_events_rounded,
            title: 'Top produse comandate',
          ),
          const SizedBox(height: 12),
          if (topProducts.isEmpty)
            _emptySmallCard('Nu există produse comandate încă.')
          else
            _topProductsCard(topProducts),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(Map<String, dynamic> data) {
    final ordersByDay = List<int>.from(data['ordersByDay'] as List);
    final spots = ordersByDay
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    final maxOrders = ordersByDay.isEmpty
        ? 1
        : ordersByDay.reduce((a, b) => math.max(a, b));
    final maxY = math.max(2, maxOrders + 1).toDouble();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.timeline_rounded,
            title: 'Comenzi în ultimele 7 zile',
          ),
          const SizedBox(height: 12),
          Container(
            height: 220,
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
            decoration: _cardDecoration(),
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 6,
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: mutedColor.withOpacity(0.10),
                    strokeWidth: 1,
                  ),
                  getDrawingVerticalLine: (_) => FlLine(
                    color: mutedColor.withOpacity(0.08),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (v, _) {
                        const labels = ['-6', '-5', '-4', '-3', '-2', 'Ieri', 'Azi'];
                        final i = v.toInt();

                        if (i < 0 || i >= labels.length) {
                          return const SizedBox();
                        }

                        return Text(
                          labels[i],
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: teal,
                    barWidth: 3,
                    dotData: FlDotData(
                      getDotPainter: (_, __, ___, ____) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: teal,
                          strokeColor: bg,
                          strokeWidth: 2,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          teal.withOpacity(0.28),
                          teal.withOpacity(0.00),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _statusTile(
                  label: 'Noi',
                  value: '${data['newOrders']}',
                  color: warning,
                  icon: Icons.fiber_new_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusTile(
                  label: 'În curs',
                  value: '${data['processingOrders']}',
                  color: processingBlue,
                  icon: Icons.sync_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statusTile(
                  label: 'Finalizate',
                  value: '${data['completedOrders']}',
                  color: success,
                  icon: Icons.check_circle_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Total comenzi', '${data['totalOrders']}', teal),
          const SizedBox(height: 8),
          _buildSummaryRow('Comenzi astăzi', '${data['ordersToday']}', processingBlue),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Rată finalizare',
            '${data['completionRate']}%',
            success,
          ),
          const SizedBox(height: 8),
          _buildSummaryRow(
            'Cantitate total comandată',
            '${data['totalOrderedQty']} buc',
            teal,
          ),
        ],
      ),
    );
  }

  Widget _buildStockTab(Map<String, dynamic> data) {
    final statuses = [
      {'label': 'OK', 'count': data['ok'], 'color': success},
      {'label': 'Scăzut', 'count': data['low'], 'color': warning},
      {'label': 'Critic', 'count': data['critical'], 'color': danger},
    ];

    final total = statuses.fold<int>(0, (s, e) => s + _toInt(e['count']));
    final lowStockProducts =
    List<Map<String, dynamic>>.from(data['lowStockProducts']);

    if (total == 0) {
      return _emptyTab('Nu există produse configurate încă.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.pie_chart_rounded,
            title: 'Distribuție stocuri',
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 42,
                      sections: statuses.map((s) {
                        final color = s['color'] as Color;
                        final count = _toInt(s['count']);

                        return PieChartSectionData(
                          value: count.toDouble(),
                          color: color,
                          radius: 38,
                          title: '$count',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: statuses.map((s) {
                      final count = _toInt(s['count']);
                      final color = s['color'] as Color;
                      final pct = total == 0 ? 0 : ((count / total) * 100).round();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                s['label'].toString(),
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '$pct%',
                              style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Total stoc', '${data['totalStock']} buc', teal),
          const SizedBox(height: 8),
          _buildSummaryRow('Capacitate totală', '${data['totalMaxStock']} buc', teal),
          const SizedBox(height: 8),
          _buildSummaryRow('Ocupare depozit', '${data['occupancy']}%', success),
          const SizedBox(height: 18),
          _sectionTitle(
            icon: Icons.inventory_2_rounded,
            title: 'Produse cu cel mai mic stoc',
          ),
          const SizedBox(height: 12),
          if (lowStockProducts.isEmpty)
            _emptySmallCard('Nu există produse de afișat.')
          else
            ...lowStockProducts.map((p) => _stockProductCard(p)),
        ],
      ),
    );
  }

  Widget _topProductsCard(List<Map<String, dynamic>> topProducts) {
    final maxQty = topProducts.fold<int>(
      0,
          (m, p) => _toInt(p['qty']) > m ? _toInt(p['qty']) : m,
    );

    final colors = [teal, midBlue, warning, success, danger];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        children: topProducts.asMap().entries.map((e) {
          final p = e.value;
          final color = colors[e.key % colors.length];
          final progress = maxQty == 0 ? 0.0 : _toInt(p['qty']) / maxQty;

          return Padding(
            padding: EdgeInsets.only(
              bottom: e.key == topProducts.length - 1 ? 0 : 16,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Center(
                        child: Text(
                          '${e.key + 1}',
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p['name'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${p['qty']} buc',
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: mutedColor.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _stockProductCard(Map<String, dynamic> p) {
    final color = p['color'] as Color? ?? teal;
    final quantity = _toInt(p['quantity']);
    final maxStock = _toInt(p['maxStock']);
    final percent = _toInt(p['stockPercent']);
    final unit = p['unit']?.toString() ?? 'buc';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  p['status'] == 'Critic'
                      ? Icons.error_rounded
                      : Icons.inventory_2_rounded,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['name'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${p['boxId']} · ${p['status']}',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$quantity/$maxStock',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: mutedColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '$percent% ocupare',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                '${p['deficit']} $unit până la maxim',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniSummary({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              color: mutedColor,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusTile({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, color: teal, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: mutedColor,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _successCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: success.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: success, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptySmallCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: mutedColor,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _emptyTab(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: mutedColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: cardBg,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    );
  }
}