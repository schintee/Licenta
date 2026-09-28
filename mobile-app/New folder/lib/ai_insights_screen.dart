import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class AiInsightsScreen extends StatefulWidget {
  const AiInsightsScreen({super.key});

  @override
  State<AiInsightsScreen> createState() => _AiInsightsScreenState();
}

class _AiInsightsScreenState extends State<AiInsightsScreen> {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const warning = Color(0xFFE8A44A);
  static const success = Color(0xFF4CAF82);

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  bool _historySaveRunning = false;
  String _lastHistorySignature = '';

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  Color get bg => isDark ? darkBlue : light;
  Color get cardBg => isDark ? const Color(0xFF0F3244) : Colors.white;
  Color get headerBg => isDark ? const Color(0xFF08263A) : Colors.white;
  Color get textColor => isDark ? light : darkBlue;
  Color get mutedColor =>
      isDark ? light.withOpacity(0.55) : darkBlue.withOpacity(0.48);
  Color get border =>
      isDark ? teal.withOpacity(0.20) : midBlue.withOpacity(0.13);

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  String _todayKey() {
    return _dateKey(DateTime.now());
  }

  String _dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDateKey(String key) {
    try {
      final parts = key.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String _formatAverageConsumption(double value) {
    if (value <= 0 || value.isNaN || value.isInfinite) {
      return '-';
    }

    return '≈ ${value.ceil()} buc/zi';
  }

  String _formatDays(dynamic value) {
    if (value is double && value.isFinite && value > 0) {
      return '≈ ${value.ceil()} zile';
    }
    return 'Date insuficiente';
  }

  void _scheduleSaveTodayHistory(List<Map<String, dynamic>> products) {
    final today = _todayKey();

    final signature = products
        .map((p) => '${p['productId']}:${p['quantity']}')
        .join('|');

    final fullSignature = '$today|$signature';

    if (_historySaveRunning || _lastHistorySignature == fullSignature) {
      return;
    }

    _lastHistorySignature = fullSignature;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _saveTodayHistory(products);
    });
  }

  Future<void> _saveTodayHistory(List<Map<String, dynamic>> products) async {
    if (_historySaveRunning) return;

    _historySaveRunning = true;

    try {
      final today = _todayKey();

      final stockHistorySnapshot = await _db.child('stockHistory').get();

      if (stockHistorySnapshot.exists &&
          stockHistorySnapshot.value != null &&
          stockHistorySnapshot.value is! Map) {
        await _db.child('stockHistory').set({});
      }

      final Map<String, dynamic> updates = {};

      for (final p in products) {
        final productId = p['productId']?.toString() ?? '';
        final quantity = _toInt(p['quantity']);

        if (productId.isEmpty) continue;

        final ref = _db.child('stockHistory/$productId/$today');
        final snapshot = await ref.get();

        if (!snapshot.exists || snapshot.value == null) {
          updates['stockHistory/$productId/$today'] = {
            'quantity': quantity,
            'timestamp': ServerValue.timestamp,
          };
          continue;
        }

        final existing = _safeMap(snapshot.value);

        if (existing.isEmpty) {
          updates['stockHistory/$productId/$today'] = {
            'quantity': quantity,
            'timestamp': ServerValue.timestamp,
          };
          continue;
        }

        final oldQuantity = _toInt(existing['quantity']);

        if (oldQuantity != quantity) {
          updates['stockHistory/$productId/$today/quantity'] = quantity;
          updates['stockHistory/$productId/$today/updatedAt'] =
              ServerValue.timestamp;
        }
      }

      if (updates.isNotEmpty) {
        await _db.update(updates);
      }
    } catch (e) {
      debugPrint('AI Insights history save error: $e');
    } finally {
      _historySaveRunning = false;
    }
  }

  List<Map<String, dynamic>> _historyPointsLast14Days({
    required Map<String, dynamic> historyForProduct,
    required int currentQuantity,
  }) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    final from = todayOnly.subtract(const Duration(days: 13));

    final points = <Map<String, dynamic>>[];

    for (final entry in historyForProduct.entries) {
      final date = _parseDateKey(entry.key.toString());
      if (date == null) continue;

      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly.isBefore(from) || dateOnly.isAfter(todayOnly)) {
        continue;
      }

      final item = _safeMap(entry.value);
      if (item.isEmpty) continue;

      points.add({
        'date': dateOnly,
        'quantity': _toInt(item['quantity']),
      });
    }

    final todayExists = points.any((p) {
      final d = p['date'] as DateTime;
      return _dateKey(d) == _dateKey(todayOnly);
    });

    if (!todayExists) {
      points.add({
        'date': todayOnly,
        'quantity': currentQuantity,
      });
    }

    points.sort((a, b) {
      final da = a['date'] as DateTime;
      final db = b['date'] as DateTime;
      return da.compareTo(db);
    });

    return points;
  }

  double _calculateAverageConsumption14Days(
      List<Map<String, dynamic>> points,
      ) {
    if (points.length < 2) return 0.0;

    double totalDrop = 0.0;
    int totalDays = 0;

    for (int i = 1; i < points.length; i++) {
      final previousDate = points[i - 1]['date'] as DateTime;
      final currentDate = points[i]['date'] as DateTime;

      final previousQuantity = _toInt(points[i - 1]['quantity']);
      final currentQuantity = _toInt(points[i]['quantity']);

      final days = currentDate.difference(previousDate).inDays;
      if (days <= 0) continue;

      final drop = previousQuantity - currentQuantity;

      if (drop > 0) {
        totalDrop += drop;
      }

      totalDays += days;
    }

    if (totalDays <= 0 || totalDrop <= 0) return 0.0;

    return totalDrop / totalDays;
  }

  bool _detectAnomaly(List<Map<String, dynamic>> points, double avg) {
    if (points.length < 2 || avg <= 0) return false;

    final yesterday = _toInt(points[points.length - 2]['quantity']);
    final today = _toInt(points.last['quantity']);
    final drop = yesterday - today;

    return drop > avg * 2.5 && drop >= 2;
  }

  List<int> _buildForecast7Days({
    required int quantity,
    required double averageConsumption,
  }) {
    final forecast = <int>[];

    for (int i = 1; i <= 7; i++) {
      final estimated = quantity - (averageConsumption * i);
      forecast.add(estimated <= 0 ? 0 : estimated.ceil());
    }

    return forecast;
  }

  int _calculateRiskScore({
    required int quantity,
    required int red,
    required int yellow,
    required double averageConsumption,
    required double remainingDays,
    required bool anomaly,
  }) {
    int score = 0;

    if (quantity <= red) {
      score += 45;
    } else if (quantity <= yellow) {
      score += 30;
    } else {
      score += 10;
    }

    if (remainingDays.isFinite) {
      if (remainingDays <= 3) {
        score += 35;
      } else if (remainingDays <= 7) {
        score += 25;
      } else if (remainingDays <= 14) {
        score += 15;
      }
    }

    if (averageConsumption > 0) score += 5;
    if (anomaly) score += 15;

    return score.clamp(0, 100);
  }

  String _rotationLabel(double averageConsumption) {
    if (averageConsumption >= 3) return 'Rotație mare';
    if (averageConsumption > 0 && averageConsumption < 1) return 'Rotație mică';
    if (averageConsumption >= 1) return 'Rotație normală';
    return 'Fără consum detectat';
  }

  Map<String, dynamic> _buildInsights(Map<String, dynamic> root) {
    final boxes = _safeMap(root['boxes']);
    final products = _safeMap(root['products']);
    final history = _safeMap(root['stockHistory']);

    if (boxes.isEmpty || products.isEmpty) {
      return {
        'products': <Map<String, dynamic>>[],
        'criticalCount': 0,
        'lowCount': 0,
        'recommendations': <Map<String, dynamic>>[],
        'anomalies': <Map<String, dynamic>>[],
        'fastestRisk': null,
      };
    }

    final result = <Map<String, dynamic>>[];
    final recommendations = <Map<String, dynamic>>[];
    final anomalies = <Map<String, dynamic>>[];

    int criticalCount = 0;
    int lowCount = 0;

    for (final entry in products.entries) {
      final productId = entry.key.toString();
      final product = _safeMap(entry.value);

      if (product['active'] == false) continue;

      final boxId = product['boxId']?.toString() ?? '';
      if (boxId.isEmpty || !boxes.containsKey(boxId)) continue;

      final box = _safeMap(boxes[boxId]);

      final quantity = _toInt(box['quantity']);
      final maxStock = _toInt(product['maxStock']);
      final red = _toInt(product['redThreshold']);
      final yellow = _toInt(product['yellowThreshold']);

      final historyForProduct = _safeMap(history[productId]);

      final points = _historyPointsLast14Days(
        historyForProduct: historyForProduct,
        currentQuantity: quantity,
      );

      final averageConsumption = _calculateAverageConsumption14Days(points);

      double remainingDays = double.infinity;

      if (averageConsumption > 0 && quantity > 0) {
        remainingDays = quantity / averageConsumption;
      }

      final anomaly = _detectAnomaly(points, averageConsumption);

      String status;
      Color color;

      if (quantity <= red) {
        status = 'Critic';
        color = danger;
        criticalCount++;
      } else if (quantity <= yellow) {
        status = 'Scăzut';
        color = warning;
        lowCount++;
      } else {
        status = 'OK';
        color = success;
      }

      final forecast7Days = _buildForecast7Days(
        quantity: quantity,
        averageConsumption: averageConsumption,
      );

      final riskScore = _calculateRiskScore(
        quantity: quantity,
        red: red,
        yellow: yellow,
        averageConsumption: averageConsumption,
        remainingDays: remainingDays,
        anomaly: anomaly,
      );

      final healthScore = (100 - riskScore).clamp(0, 100);
      final rotation = _rotationLabel(averageConsumption);

      String recommendation = 'Stoc stabil. Nu este necesară comandă.';
      int suggestedOrder = 0;
      int priority = 1;

      if (quantity <= red) {
        recommendation =
        'Reaprovizionare urgentă. Stocul este sub pragul critic.';
        suggestedOrder = (maxStock - quantity).clamp(1, 999999);
        priority = 5;
      } else if (quantity <= yellow) {
        recommendation = 'Reaprovizionare recomandată în curând.';
        suggestedOrder = (maxStock - quantity).clamp(1, 999999);
        priority = 4;
      } else if (remainingDays.isFinite && remainingDays <= 7) {
        recommendation =
        'Stocul se poate epuiza în mai puțin de 7 zile. Recomand comandă preventivă.';
        suggestedOrder = (maxStock - quantity).clamp(1, 999999);
        priority = 4;
      } else if (rotation == 'Rotație mare' && quantity < maxStock * 0.6) {
        recommendation =
        'Produs cu rotație mare. Recomand completarea stocului pentru siguranță.';
        suggestedOrder = (maxStock - quantity).clamp(1, 999999);
        priority = 3;
      }

      final row = {
        'productId': productId,
        'name': product['name']?.toString() ?? 'Produs',
        'boxId': boxId,
        'quantity': quantity,
        'maxStock': maxStock,
        'unit': product['unit']?.toString() ?? 'buc',
        'redThreshold': red,
        'yellowThreshold': yellow,
        'status': status,
        'color': color,
        'averageConsumption': averageConsumption,
        'remainingDays': remainingDays,
        'recommendation': recommendation,
        'suggestedOrder': suggestedOrder,
        'priority': priority,
        'anomaly': anomaly,
        'riskScore': riskScore,
        'healthScore': healthScore,
        'forecast7Days': forecast7Days,
        'rotation': rotation,
      };

      result.add(row);

      if (priority >= 4) recommendations.add(row);
      if (anomaly) anomalies.add(row);
    }

    recommendations.sort(
          (a, b) => _toInt(b['priority']).compareTo(_toInt(a['priority'])),
    );

    result.sort((a, b) {
      final aRisk = _toInt(a['riskScore']);
      final bRisk = _toInt(b['riskScore']);
      return bRisk.compareTo(aRisk);
    });

    final riskyProducts = result.where((p) {
      final days = p['remainingDays'];
      return days is double && days.isFinite;
    }).toList();

    riskyProducts.sort((a, b) {
      final aDays = a['remainingDays'] as double;
      final bDays = b['remainingDays'] as double;
      return aDays.compareTo(bDays);
    });

    return {
      'products': result,
      'criticalCount': criticalCount,
      'lowCount': lowCount,
      'recommendations': recommendations,
      'anomalies': anomalies,
      'fastestRisk': riskyProducts.isEmpty ? null : riskyProducts.first,
    };
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
              child: StreamBuilder<DatabaseEvent>(
                stream: _db.onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: teal),
                    );
                  }

                  if (!snapshot.hasData ||
                      snapshot.data?.snapshot.value == null) {
                    return _emptyState();
                  }

                  final root = _safeMap(snapshot.data!.snapshot.value);
                  final insights = _buildInsights(root);
                  final products =
                  List<Map<String, dynamic>>.from(insights['products']);

                  _scheduleSaveTodayHistory(products);

                  return ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      _buildHeroCard(insights),
                      const SizedBox(height: 16),
                      _buildStatsRow(insights),
                      const SizedBox(height: 16),
                      _sectionTitle('Recomandări inteligente'),
                      const SizedBox(height: 10),
                      _buildRecommendations(insights),
                      const SizedBox(height: 18),
                      _sectionTitle('Predicții pe produse'),
                      const SizedBox(height: 10),
                      ...products.map(_buildPredictionCard),
                    ],
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: headerBg,
        border: Border(
          bottom: BorderSide(color: border, width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'AI Insights',
              style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: teal.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: teal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(Map<String, dynamic> insights) {
    final fastest = insights['fastestRisk'];

    String text =
        'Sistemul analizează istoricul stocurilor și generează recomandări automate.';

    if (fastest is Map<String, dynamic>) {
      final name = fastest['name'];
      final days = fastest['remainingDays'];

      if (days is double && days.isFinite) {
        text = '$name se poate epuiza în aproximativ ${days.ceil()} zile.';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF0F3244), const Color(0xFF1D546D)]
              : [Colors.white, const Color(0xFFE8F3F3)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: teal.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: teal,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analiză predictivă StockIQ',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(Map<String, dynamic> insights) {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            'Critice',
            '${insights['criticalCount']}',
            Icons.warning_rounded,
            danger,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            'Scăzute',
            '${insights['lowCount']}',
            Icons.trending_down_rounded,
            warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _miniStat(
            'Anomalii',
            '${List.from(insights['anomalies']).length}',
            Icons.report_problem_rounded,
            teal,
          ),
        ),
      ],
    );
  }

  Widget _miniStat(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: mutedColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        color: textColor,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _buildRecommendations(Map<String, dynamic> insights) {
    final recommendations =
    List<Map<String, dynamic>>.from(insights['recommendations']);

    if (recommendations.isEmpty) {
      return _infoCard(
        icon: Icons.check_circle_rounded,
        title: 'Nu există produse în risc',
        text: 'Stocurile sunt stabile pe baza datelor disponibile.',
        color: success,
      );
    }

    return Column(
      children: recommendations.map((p) {
        return _infoCard(
          icon: Icons.auto_awesome_rounded,
          title: p['name'].toString(),
          text:
          '${p['recommendation']} Cantitate sugerată: ${p['suggestedOrder']} ${p['unit']}.',
          color: _toInt(p['priority']) >= 5 ? danger : warning,
        );
      }).toList(),
    );
  }

  Widget _buildPredictionCard(Map<String, dynamic> p) {
    final days = p['remainingDays'];
    final avg = _toDouble(p['averageConsumption']);
    final riskScore = _toInt(p['riskScore']);
    final healthScore = _toInt(p['healthScore']);
    final forecast = List<int>.from(p['forecast7Days'] ?? []);

    String daysText = _formatDays(days);

    if (avg <= 0) {
      daysText = 'Consum insuficient';
    }

    final color = p['color'] is Color ? p['color'] as Color : teal;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.18),
                child: Icon(Icons.inventory_2_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  p['name'].toString(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              _statusChip(p['status'].toString(), color),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _smallInfo(
                  'Stoc actual',
                  '${p['quantity']} ${p['unit']}',
                ),
              ),
              Expanded(
                child: _smallInfo(
                  'Consum mediu',
                  _formatAverageConsumption(avg),
                ),
              ),
              Expanded(
                child: _smallInfo(
                  'Epuizare',
                  daysText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _smallInfo(
                  'AI Risk',
                  '$riskScore%',
                ),
              ),
              Expanded(
                child: _smallInfo(
                  'AI Health',
                  '$healthScore%',
                ),
              ),
              Expanded(
                child: _smallInfo(
                  'Rotație',
                  p['rotation'].toString(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Forecast 7 zile: ${forecast.join(' → ')} ${p['unit']}',
            style: TextStyle(
              color: mutedColor,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            p['recommendation'].toString(),
            style: TextStyle(
              color: mutedColor,
              fontSize: 13,
            ),
          ),
          if (p['anomaly'] == true) ...[
            const SizedBox(height: 10),
            Text(
              '⚠ Consum anormal detectat.',
              style: TextStyle(
                color: danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: mutedColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _statusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String text,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.16),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Text(
        'Nu există date disponibile.',
        style: TextStyle(color: mutedColor),
      ),
    );
  }
}