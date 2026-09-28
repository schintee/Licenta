import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen>
    with SingleTickerProviderStateMixin {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const warning = Color(0xFFE8A44A);
  static const success = Color(0xFF4CAF82);

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  MobileScannerController? _cameraController;

  bool _hasScanned = false;
  bool _torchOn = false;
  bool _showResult = false;
  bool _loadingBox = false;

  Map<String, dynamic>? _boxData;

  late AnimationController _lineCtrl;
  late Animation<double> _lineAnim;

  @override
  void initState() {
    super.initState();

    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _lineAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _lineCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_hasScanned) return;

    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;

    if (code == null || code.trim().isEmpty) return;

    setState(() {
      _hasScanned = true;
      _loadingBox = true;
    });

    await _cameraController?.stop();

    await _loadBoxFromFirebase(code.trim());
  }

  Future<void> _loadBoxFromFirebase(String code) async {
    try {
      final normalizedCode = code.toLowerCase().replaceAll(' ', '');

      final boxSnap = await _db.child('boxes/$normalizedCode').get();

      if (!boxSnap.exists || boxSnap.value == null) {
        setState(() {
          _boxData = {
            'found': false,
            'boxId': code,
          };
          _showResult = true;
          _loadingBox = false;
        });
        return;
      }

      final box = Map<String, dynamic>.from(boxSnap.value as Map);
      final productId = box['productId']?.toString() ?? '';
      Map<String, dynamic>? product;

      if (productId.isNotEmpty) {
        final productSnap = await _db.child('products/$productId').get();

        if (productSnap.exists && productSnap.value != null) {
          product = Map<String, dynamic>.from(productSnap.value as Map);
        }
      }

      setState(() {
        _boxData = {
          'found': true,
          'boxId': normalizedCode,
          'boxName': box['name']?.toString() ?? normalizedCode,
          'productId': productId,
          'productName': product?['name']?.toString() ?? 'Produs neconfigurat',
          'unit': product?['unit']?.toString() ?? 'buc',
          'quantity': _toInt(box['quantity']),
          'maxStock': _toInt(product?['maxStock']),
          'yellowThreshold': _toInt(product?['yellowThreshold']),
          'redThreshold': _toInt(product?['redThreshold']),
          'initialized': box['initialized'] == true,
          'lastWeightRaw': _toInt(box['lastWeightRaw']),
          'productWeightRaw': _toInt(box['productWeightRaw']),
        };
        _showResult = true;
        _loadingBox = false;
      });
    } catch (_) {
      setState(() {
        _boxData = {
          'found': false,
          'boxId': code,
        };
        _showResult = true;
        _loadingBox = false;
      });
    }
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  void _resetScan() {
    setState(() {
      _hasScanned = false;
      _showResult = false;
      _loadingBox = false;
      _boxData = null;
    });

    _cameraController?.start();
  }

  Color _stockColor(Map<String, dynamic> data) {
    final qty = _toInt(data['quantity']);
    final red = _toInt(data['redThreshold']);
    final yellow = _toInt(data['yellowThreshold']);

    if (qty <= red) return danger;
    if (qty <= yellow) return warning;
    return success;
  }

  String _stockLabel(Map<String, dynamic> data) {
    final qty = _toInt(data['quantity']);
    final red = _toInt(data['redThreshold']);
    final yellow = _toInt(data['yellowThreshold']);

    if (qty <= red) return 'Critic';
    if (qty <= yellow) return 'Stoc scăzut';
    return 'OK';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBlue,
      body: Stack(
        children: [
          if (!_showResult)
            MobileScanner(
              controller: _cameraController!,
              onDetect: _onDetect,
            ),
          if (_showResult) Container(color: darkBlue),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                if (_loadingBox)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: teal),
                    ),
                  ),
                if (!_showResult && !_loadingBox) ...[
                  const Spacer(),
                  _buildViewfinder(),
                  const SizedBox(height: 24),
                  Text(
                    'Scanează codul QR: box1, box2 sau box3',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  _buildTorchButton(),
                  const SizedBox(height: 40),
                ],
                if (_showResult && _boxData != null)
                  Expanded(child: _buildResult()),
              ],
            ),
          ),
          if (!_showResult && !_loadingBox) _buildDarkOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'Scanează cutia',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          if (_showResult) ...[
            const Spacer(),
            GestureDetector(
              onTap: _resetScan,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: teal.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: teal.withOpacity(0.40),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.qr_code_scanner_rounded,
                      color: teal,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Din nou',
                      style: TextStyle(
                        color: teal,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildViewfinder() {
    const size = 240.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          CustomPaint(
            size: const Size(size, size),
            painter: _ViewfinderPainter(),
          ),
          AnimatedBuilder(
            animation: _lineAnim,
            builder: (_, __) {
              return Positioned(
                top: 10 + (size - 20) * _lineAnim.value,
                left: 16,
                right: 16,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Colors.transparent,
                        teal,
                        Colors.transparent,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDarkOverlay() {
    return IgnorePointer(
      child: CustomPaint(
        size: MediaQuery.of(context).size,
        painter: _OverlayPainter(),
      ),
    );
  }

  Widget _buildTorchButton() {
    return GestureDetector(
      onTap: () {
        _cameraController?.toggleTorch();
        setState(() => _torchOn = !_torchOn);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: _torchOn ? teal.withOpacity(0.25) : Colors.white.withOpacity(0.10),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _torchOn ? teal.withOpacity(0.60) : Colors.white.withOpacity(0.20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _torchOn
                  ? Icons.flashlight_on_rounded
                  : Icons.flashlight_off_rounded,
              color: _torchOn ? teal : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _torchOn ? 'Lanternă pornită' : 'Lanternă',
              style: TextStyle(
                color: _torchOn ? teal : Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final data = _boxData!;

    if (data['found'] != true) {
      return _buildNotFound(data['boxId'].toString());
    }

    final col = _stockColor(data);
    final qty = _toInt(data['quantity']);
    final maxStock = _toInt(data['maxStock']);
    final progress = maxStock == 0 ? 0.0 : qty / maxStock;

    final product = {
      'productId': data['productId'],
      'code': data['productId'],
      'name': data['productName'],
      'unit': data['unit'],
      'boxId': data['boxId'],
      'quantity': data['quantity'],
      'maxStock': data['maxStock'],
      'yellowThreshold': data['yellowThreshold'],
      'redThreshold': data['redThreshold'],
      'deficit': (maxStock - qty).clamp(1, 99999),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: success.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: success.withOpacity(0.30),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: success,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cutie identificată',
                        style: TextStyle(
                          color: success,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['boxId'].toString(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _infoRow(Icons.inventory_2_rounded, 'Cutie', data['boxName'].toString()),
          const SizedBox(height: 10),
          _infoRow(Icons.scale_rounded, 'Raw curent', data['lastWeightRaw'].toString()),
          const SizedBox(height: 20),
          Text(
            'PRODUS ÎN CUTIE',
            style: TextStyle(
              color: Colors.white.withOpacity(0.40),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F3244),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: col.withOpacity(0.25),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: col,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: col.withOpacity(0.55),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        data['productName'].toString(),
                        style: const TextStyle(
                          color: light,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      _stockLabel(data),
                      style: TextStyle(
                        color: col,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '$qty',
                      style: TextStyle(
                        color: col,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      ' / $maxStock ${data['unit']}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: AlwaysStoppedAnimation(col),
                    minHeight: 7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/create-order',
                  arguments: {
                    'prefill': [product],
                  },
                );
              },
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: const Text(
                'Creează comandă',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: midBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound(String code) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: danger,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Cutie negăsită',
              style: TextStyle(
                color: light,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Nu există "$code" în Firebase. Scanează box1, box2 sau box3.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _resetScan,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Scanează din nou'),
              style: ElevatedButton.styleFrom(
                backgroundColor: midBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: teal, size: 18),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 13,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: light,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5F9598)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;
    const r = 12.0;
    final w = size.width;
    final h = size.height;

    canvas.drawLine(const Offset(r, 0), const Offset(cornerLen, 0), paint);
    canvas.drawLine(const Offset(0, r), const Offset(0, cornerLen), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, 0, r * 2, r * 2),
      3.14,
      1.57,
      false,
      paint,
    );

    canvas.drawLine(Offset(w - cornerLen, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, cornerLen), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2),
      -1.57,
      1.57,
      false,
      paint,
    );

    canvas.drawLine(Offset(0, h - cornerLen), Offset(0, h - r), paint);
    canvas.drawLine(Offset(r, h), Offset(cornerLen, h), paint);
    canvas.drawArc(
      Rect.fromLTWH(0, h - r * 2, r * 2, r * 2),
      1.57,
      1.57,
      false,
      paint,
    );

    canvas.drawLine(Offset(w, h - cornerLen), Offset(w, h - r), paint);
    canvas.drawLine(Offset(w - cornerLen, h), Offset(w - r, h), paint);
    canvas.drawArc(
      Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2),
      0,
      1.57,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const viewfinderSize = 240.0;
    final cx = size.width / 2;
    final cy = size.height / 2 - 40;

    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: viewfinderSize,
      height: viewfinderSize,
    );

    final paint = Paint()..color = Colors.black.withOpacity(0.55);
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      )
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}