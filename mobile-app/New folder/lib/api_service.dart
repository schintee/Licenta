import 'package:firebase_database/firebase_database.dart';

class ApiService {
  static final FirebaseDatabase _db = FirebaseDatabase.instance;

  static DatabaseReference get _boxesRef => _db.ref('boxes');
  static DatabaseReference get _productsRef => _db.ref('products');
  static DatabaseReference get _ordersRef => _db.ref('orders');
  static DatabaseReference get _commandsRef => _db.ref('commands');

  static const String testEmail = 'admin@test.com';
  static const String testPassword = '123456';

  static Future<Map<String, dynamic>?> login(
      String email,
      String password,
      ) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (email.trim() == testEmail && password.trim() == testPassword) {
      return {
        'id': 1,
        'full_name': 'Administrator',
        'role': 'Admin · Depozit',
      };
    }

    return null;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getBoxes() async {
    final rootSnap = await _db.ref().get();

    if (!rootSnap.exists || rootSnap.value == null) return [];

    final root = Map<String, dynamic>.from(rootSnap.value as Map);

    final boxes = root['boxes'] == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(root['boxes'] as Map);

    final products = root['products'] == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(root['products'] as Map);

    return boxes.entries.map((entry) {
      final boxId = entry.key;
      final box = Map<String, dynamic>.from(entry.value as Map);

      final productId = box['productId']?.toString() ?? 'product_$boxId';
      final product = products[productId] == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(products[productId] as Map);

      return {
        'id': boxId,
        'box_id': boxId,
        'box_qr': boxId,
        'name': box['name'] ?? boxId,
        'productId': productId,
        'productName': product['name'] ?? '',
        'unit': product['unit'] ?? 'buc',
        'quantity': _toInt(box['quantity']),
        'maxStock': _toInt(product['maxStock']),
        'yellowThreshold': _toInt(product['yellowThreshold']),
        'redThreshold': _toInt(product['redThreshold']),
        'initialized': box['initialized'] ?? false,
        'emptyRaw': _toInt(box['emptyRaw']),
        'oneProductRaw': _toInt(box['oneProductRaw']),
        'productWeightRaw': _toInt(box['productWeightRaw']),
        'lastWeightRaw': _toInt(box['lastWeightRaw']),
        'lastUpdate': _toInt(box['lastUpdate']),
      };
    }).toList();
  }

  static Future<Map<String, dynamic>?> getBox(String qrCode) async {
    final boxId = qrCode.trim().toLowerCase().replaceAll(' ', '');

    final boxSnap = await _boxesRef.child(boxId).get();

    if (!boxSnap.exists || boxSnap.value == null) return null;

    final box = Map<String, dynamic>.from(boxSnap.value as Map);

    final productId = box['productId']?.toString() ?? 'product_$boxId';
    final productSnap = await _productsRef.child(productId).get();

    final product = productSnap.exists && productSnap.value != null
        ? Map<String, dynamic>.from(productSnap.value as Map)
        : <String, dynamic>{};

    return {
      'box_id': boxId,
      'box_qr': boxId,
      'location': box['name'] ?? boxId,
      'description': box['initialized'] == true
          ? 'Cutie inițializată'
          : 'Cutie neinițializată',
      'products': [
        {
          'id': productId,
          'productId': productId,
          'code': productId,
          'boxId': boxId,
          'name': product['name'] ?? 'Produs neconfigurat',
          'unit': product['unit'] ?? 'buc',
          'maxStock': _toInt(product['maxStock']),
          'yellowThreshold': _toInt(product['yellowThreshold']),
          'redThreshold': _toInt(product['redThreshold']),
          'quantity': _toInt(box['quantity']),
        }
      ],
    };
  }

  static Future<List<Map<String, dynamic>>> getCriticalStock() async {
    final boxes = await getBoxes();

    return boxes.where((box) {
      final initialized = box['initialized'] == true;
      final quantity = _toInt(box['quantity']);
      final yellowThreshold = _toInt(box['yellowThreshold']);

      return initialized && quantity <= yellowThreshold;
    }).map((box) {
      return {
        'productId': box['productId'],
        'product_id': box['productId'],
        'code': box['productId'],
        'boxId': box['box_id'],
        'name': box['productName'] == ''
            ? 'Produs neconfigurat'
            : box['productName'],
        'unit': box['unit'] ?? 'buc',
        'maxStock': box['maxStock'] ?? 0,
        'yellowThreshold': box['yellowThreshold'] ?? 0,
        'redThreshold': box['redThreshold'] ?? 0,
        'quantity': box['quantity'] ?? 0,
        'deficit': (_toInt(box['maxStock']) - _toInt(box['quantity']))
            .clamp(0, 999999),
        'box_qr': box['box_id'],
        'location': box['name'] ?? '',
      };
    }).toList();
  }

  static Future<String?> createOrder({
    required int userId,
    required List<Map<String, dynamic>> items,
    String notes = '',
  }) async {
    final newOrder = _ordersRef.push();

    await newOrder.set({
      'userId': userId,
      'createdBy': 'Administrator',
      'notes': notes,
      'status': 'new',
      'createdAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
      'items': items.map((item) {
        return {
          'productId': item['productId'] ?? item['product_id'],
          'productName': item['productName'] ?? item['product_name'],
          'name': item['productName'] ?? item['product_name'],
          'productCode': item['productCode'] ?? item['product_code'],
          'boxId': item['boxId'] ?? '',
          'quantity': _toInt(item['quantity']),
          'unit': item['unit'] ?? 'buc',
        };
      }).toList(),
    });

    return newOrder.key;
  }

  static Future<List<Map<String, dynamic>>> getOrders() async {
    final snapshot = await _ordersRef.get();

    if (!snapshot.exists || snapshot.value == null) return [];

    final data = Map<String, dynamic>.from(snapshot.value as Map);

    final orders = data.entries.map((entry) {
      final value = Map<String, dynamic>.from(entry.value as Map);

      return {
        'id': entry.key,
        'order_id': entry.key,
        'status': value['status'] ?? 'new',
        'notes': value['notes'] ?? '',
        'created_at': value['createdAt'] ?? value['created_at'] ?? 0,
        'user': {
          'full_name': value['createdBy'] ?? 'Administrator',
        },
        'order_items': value['items'] ?? [],
      };
    }).toList();

    orders.sort((a, b) {
      final aTime = _toInt(a['created_at']);
      final bTime = _toInt(b['created_at']);
      return bTime.compareTo(aTime);
    });

    return orders;
  }

  static Future<bool> updateOrderStatus(dynamic orderId, String status) async {
    await _ordersRef.child(orderId.toString()).update({
      'status': status,
      'updatedAt': ServerValue.timestamp,
    });

    return true;
  }

  static Future<bool> deleteOrder(dynamic orderId) async {
    await _ordersRef.child(orderId.toString()).remove();
    return true;
  }

  static Future<bool> completeOrder(dynamic orderId) async {
    await _ordersRef.child(orderId.toString()).update({
      'status': 'completed',
      'completedAt': ServerValue.timestamp,
      'updatedAt': ServerValue.timestamp,
    });

    return true;
  }

  static Future<List<Map<String, dynamic>>> searchProducts(String query) async {
    final boxes = await getBoxes();
    final q = query.toLowerCase().trim();

    return boxes.where((box) {
      final productName = '${box['productName']}'.toLowerCase();
      final productId = '${box['productId']}'.toLowerCase();
      final boxId = '${box['box_id']}'.toLowerCase();

      if (q.isEmpty) return true;

      return productName.contains(q) ||
          productId.contains(q) ||
          boxId.contains(q);
    }).map((box) {
      return {
        'id': box['productId'],
        'productId': box['productId'],
        'code': box['productId'],
        'boxId': box['box_id'],
        'name': box['productName'] == ''
            ? 'Produs neconfigurat'
            : box['productName'],
        'unit': box['unit'] ?? 'buc',
        'maxStock': box['maxStock'] ?? 0,
        'yellowThreshold': box['yellowThreshold'] ?? 0,
        'redThreshold': box['redThreshold'] ?? 0,
        'quantity': box['quantity'] ?? 0,
        'box_qr': box['box_id'],
        'location': box['name'] ?? '',
      };
    }).toList();
  }

  static Future<bool> updateStock(String boxId, int quantity) async {
    await _boxesRef.child(boxId).update({
      'quantity': quantity,
      'lastUpdate': ServerValue.timestamp,
    });

    return true;
  }

  static Future<bool> requestTare(String boxId) async {
    await _commandsRef.child(boxId).update({
      'tareRequest': true,
      'tareRequestAt': ServerValue.timestamp,
    });

    return true;
  }

  static Future<bool> requestSaveOneProduct(String boxId) async {
    await _commandsRef.child(boxId).update({
      'saveOneProductRequest': true,
      'saveOneProductRequestAt': ServerValue.timestamp,
    });

    return true;
  }

  static Future<bool> saveBoxProductConfig({
    required String boxId,
    required String productName,
    required int maxStock,
    required int yellowThreshold,
    required int redThreshold,
  }) async {
    final productId = 'product_$boxId';

    await _productsRef.child(productId).update({
      'boxId': boxId,
      'name': productName,
      'unit': 'buc',
      'maxStock': maxStock,
      'yellowThreshold': yellowThreshold,
      'redThreshold': redThreshold,
      'active': true,
      'updatedAt': ServerValue.timestamp,
    });

    await _boxesRef.child(boxId).update({
      'name': 'Cutia ${boxId.replaceAll('box', '')}',
      'productId': productId,
      'initialized': true,
      'lastUpdate': ServerValue.timestamp,
    });

    return true;
  }
}