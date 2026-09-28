import 'package:firebase_database/firebase_database.dart';

class AiContextService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Future<String> buildWarehouseContext() async {
    final snapshot = await _db.get();

    if (!snapshot.exists || snapshot.value == null || snapshot.value is! Map) {
      return 'Nu există date disponibile în Firebase.';
    }

    final root = Map<String, dynamic>.from(snapshot.value as Map);

    final boxes = _safeMap(root['boxes']);
    final products = _safeMap(root['products']);
    final orders = _safeMap(root['orders']);
    final stockHistory = _safeMap(root['stockHistory']);

    final parsedProducts = <Map<String, dynamic>>[];

    int criticalCount = 0;
    int lowCount = 0;
    int okCount = 0;
    int noHistoryCount = 0;

    for (final entry in products.entries) {
      final productId = entry.key.toString();
      final product = _safeMap(entry.value);

      if (product['active'] == false) continue;

      final boxId = product['boxId']?.toString() ?? '';
      final box = _safeMap(boxes[boxId]);

      if (boxId.isEmpty || box.isEmpty) continue;

      final name = product['name']?.toString() ?? 'Produs';
      final unit = product['unit']?.toString() ?? 'buc';

      final quantity = _toInt(box['quantity']);
      final maxStock = _toInt(product['maxStock']);
      final red = _toInt(product['redThreshold']);
      final yellow = _toInt(product['yellowThreshold']);

      String status = 'OK';

      if (quantity <= red) {
        status = 'Critic';
        criticalCount++;
      } else if (quantity <= yellow) {
        status = 'Scăzut';
        lowCount++;
      } else {
        okCount++;
      }

      final historyForProduct = _safeMap(stockHistory[productId]);
      final avg = _averageConsumptionLast14Days(historyForProduct);
      final hasHistory = historyForProduct.length >= 2;

      if (!hasHistory) noHistoryCount++;

      double remainingDays = double.infinity;

      if (avg > 0 && quantity > 0) {
        remainingDays = quantity / avg;
      }

      final suggestedOrder = _suggestOrder(
        quantity: quantity,
        maxStock: maxStock,
        averageConsumption: avg,
        redThreshold: red,
        yellowThreshold: yellow,
      );

      final riskScore = _riskScore(
        quantity: quantity,
        red: red,
        yellow: yellow,
        avg: avg,
        remainingDays: remainingDays,
      );

      parsedProducts.add({
        'productId': productId,
        'name': name,
        'boxId': boxId,
        'unit': unit,
        'quantity': quantity,
        'maxStock': maxStock,
        'redThreshold': red,
        'yellowThreshold': yellow,
        'status': status,
        'averageConsumption': avg,
        'remainingDays': remainingDays,
        'suggestedOrder': suggestedOrder,
        'riskScore': riskScore,
        'hasHistory': hasHistory,
      });
    }

    parsedProducts.sort((a, b) {
      return _toInt(b['riskScore']).compareTo(_toInt(a['riskScore']));
    });

    final productsToOrder = parsedProducts.where((p) {
      final status = p['status'].toString();
      final days = p['remainingDays'];

      return status == 'Critic' ||
          status == 'Scăzut' ||
          (days is double && days.isFinite && days <= 7);
    }).toList();

    final openOrders = _countOpenOrders(orders);

    final buffer = StringBuffer();

    buffer.writeln('📦 Rezumat depozit StockIQ');
    buffer.writeln('');
    buffer.writeln('Produse totale: ${parsedProducts.length}');
    buffer.writeln('Produse OK: $okCount');
    buffer.writeln('Produse scăzute: $lowCount');
    buffer.writeln('Produse critice: $criticalCount');
    buffer.writeln('Produse fără istoric suficient: $noHistoryCount');
    buffer.writeln('Comenzi deschise: $openOrders');
    buffer.writeln('');

    if (parsedProducts.isNotEmpty) {
      final first = parsedProducts.first;
      buffer.writeln('⚠ Cel mai mare risc:');
      buffer.writeln(
        '- ${first['name']} (${first['boxId']}) · stoc ${first['quantity']} ${first['unit']} · risc ${first['riskScore']}%',
      );

      final days = first['remainingDays'];
      if (days is double && days.isFinite) {
        buffer.writeln('- estimare epuizare: aproximativ ${days.ceil()} zile');
      } else {
        buffer.writeln('- estimare epuizare: date insuficiente');
      }

      buffer.writeln('');
    }

    if (productsToOrder.isEmpty) {
      buffer.writeln('✅ Nu există produse care necesită comandă imediată.');
    } else {
      buffer.writeln('🛒 Recomandare comandă:');

      for (final p in productsToOrder.take(5)) {
        buffer.writeln(
          '- ${p['name']}: comandă ${p['suggestedOrder']} ${p['unit']} '
              '(stoc ${p['quantity']}, status ${p['status']}, risc ${p['riskScore']}%)',
        );
      }
    }

    buffer.writeln('');
    buffer.writeln('📊 Produse analizate:');

    for (final p in parsedProducts.take(8)) {
      final avg = _toDouble(p['averageConsumption']);
      final days = p['remainingDays'];

      buffer.writeln(
        '- ${p['name']} / ${p['boxId']}: '
            '${p['quantity']} ${p['unit']}, '
            '${p['status']}, '
            'consum ≈ ${avg <= 0 ? 0 : avg.ceil()} buc/zi, '
            'epuizare ${days is double && days.isFinite ? '${days.ceil()} zile' : 'necunoscută'}, '
            'risc ${p['riskScore']}%',
      );
    }

    return buffer.toString();
  }

  Map<String, dynamic> _safeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
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

  double _averageConsumptionLast14Days(Map<String, dynamic> history) {
    if (history.length < 2) return 0.0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(const Duration(days: 13));

    final points = <Map<String, dynamic>>[];

    for (final entry in history.entries) {
      final date = _parseDateKey(entry.key.toString());
      if (date == null) continue;

      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly.isBefore(from) || dateOnly.isAfter(today)) {
        continue;
      }

      final item = _safeMap(entry.value);
      if (item.isEmpty) continue;

      points.add({
        'date': dateOnly,
        'quantity': _toInt(item['quantity']),
      });
    }

    points.sort((a, b) {
      final da = a['date'] as DateTime;
      final db = b['date'] as DateTime;
      return da.compareTo(db);
    });

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

    if (totalDrop <= 0 || totalDays <= 0) return 0.0;

    return totalDrop / totalDays;
  }

  int _suggestOrder({
    required int quantity,
    required int maxStock,
    required double averageConsumption,
    required int redThreshold,
    required int yellowThreshold,
  }) {
    if (maxStock <= 0) return 0;

    final safetyStock = yellowThreshold > 0 ? yellowThreshold : 2;
    final weeklyNeed = averageConsumption <= 0 ? 0 : (averageConsumption * 7).ceil();

    int target = safetyStock + weeklyNeed;

    if (quantity <= redThreshold) {
      target = maxStock;
    } else if (quantity <= yellowThreshold) {
      target = (maxStock * 0.8).ceil();
    }

    final needed = target - quantity;

    if (needed <= 0) return 0;

    return needed.clamp(1, maxStock);
  }

  int _riskScore({
    required int quantity,
    required int red,
    required int yellow,
    required double avg,
    required double remainingDays,
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

    if (avg > 0) score += 10;

    return score.clamp(0, 100);
  }

  int _countOpenOrders(Map<String, dynamic> orders) {
    int count = 0;

    for (final entry in orders.entries) {
      final order = _safeMap(entry.value);
      final status = order['status']?.toString() ?? 'new';

      if (status == 'new' || status == 'processing') {
        count++;
      }
    }

    return count;
  }
}