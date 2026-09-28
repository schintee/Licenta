import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BoxInitScreen extends StatefulWidget {
  const BoxInitScreen({super.key});

  @override
  State<BoxInitScreen> createState() => _BoxInitScreenState();
}

class _BoxInitScreenState extends State<BoxInitScreen> {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const success = Color(0xFF4CAF82);
  static const warning = Color(0xFFE8A44A);

  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  final List<String> _boxes = ['box1', 'box2', 'box3'];

  String _selectedBox = 'box1';

  final _productController = TextEditingController();
  final _maxStockController = TextEditingController();
  final _yellowController = TextEditingController();
  final _redController = TextEditingController();

  bool _loading = false;

  Map<String, dynamic>? _boxData;
  Map<String, dynamic>? _productData;

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
    _loadBox();
  }

  @override
  void dispose() {
    _productController.dispose();
    _maxStockController.dispose();
    _yellowController.dispose();
    _redController.dispose();
    super.dispose();
  }

  Future<void> _loadBox() async {
    final boxSnap = await _db.child('boxes/$_selectedBox').get();

    Map<String, dynamic>? box;
    Map<String, dynamic>? product;

    if (boxSnap.exists && boxSnap.value != null) {
      box = Map<String, dynamic>.from(boxSnap.value as Map);

      final productId = box['productId']?.toString() ?? 'product_$_selectedBox';
      final productSnap = await _db.child('products/$productId').get();

      if (productSnap.exists && productSnap.value != null) {
        product = Map<String, dynamic>.from(productSnap.value as Map);
      }
    }

    setState(() {
      _boxData = box;
      _productData = product;

      _productController.text =
          product?['name']?.toString() ?? box?['productName']?.toString() ?? '';
      _maxStockController.text =
          product?['maxStock']?.toString() ?? box?['maxStock']?.toString() ?? '';
      _yellowController.text =
          product?['yellowThreshold']?.toString() ??
              box?['yellowThreshold']?.toString() ??
              '';
      _redController.text =
          product?['redThreshold']?.toString() ??
              box?['redThreshold']?.toString() ??
              '';
    });
  }

  Future<void> _tareBox() async {
    setState(() => _loading = true);

    await _db.child('commands/$_selectedBox').update({
      'tareRequest': true,
      'tareRequestAt': ServerValue.timestamp,
    });

    _showMessage('Cerere TARE trimisă către ESP32.', midBlue);

    setState(() => _loading = false);
  }

  Future<void> _saveOneProduct() async {
    setState(() => _loading = true);

    await _db.child('commands/$_selectedBox').update({
      'saveOneProductRequest': true,
      'saveOneProductRequestAt': ServerValue.timestamp,
    });

    _showMessage('Cerere salvare greutate produs trimisă.', success);

    setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    final name = _productController.text.trim();
    final maxStock = int.tryParse(_maxStockController.text.trim()) ?? 0;
    final yellow = int.tryParse(_yellowController.text.trim()) ?? 0;
    final red = int.tryParse(_redController.text.trim()) ?? 0;

    if (name.isEmpty || maxStock <= 0) {
      _showMessage('Completează numele produsului și stocul maxim.', danger);
      return;
    }

    if (red > yellow || yellow > maxStock) {
      _showMessage('Pragurile trebuie să fie: roșu ≤ galben ≤ stoc maxim.', danger);
      return;
    }

    setState(() => _loading = true);

    final productId = 'product_$_selectedBox';
    final qrCode = _selectedBox;

    await _db.child('products/$productId').update({
      'boxId': _selectedBox,
      'name': name,
      'unit': 'buc',
      'maxStock': maxStock,
      'yellowThreshold': yellow,
      'redThreshold': red,
      'active': true,
      'updatedAt': ServerValue.timestamp,
    });

    await _db.child('boxes/$_selectedBox').update({
      'name': 'Cutia ${_selectedBox.replaceAll('box', '')}',
      'productId': productId,
      'productName': name,
      'maxStock': maxStock,
      'yellowThreshold': yellow,
      'redThreshold': red,
      'initialized': true,
      'qrCode': qrCode,
      'lastUpdate': ServerValue.timestamp,
    });

    await _db.child('commands/$_selectedBox').update({
      'tareRequest': false,
      'saveOneProductRequest': false,
    });

    _showMessage('Configurație salvată și cod QR generat.', success);

    await _loadBox();

    setState(() => _loading = false);
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: mutedColor,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _input({
    required String label,
    required TextEditingController controller,
    TextInputType type = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            filled: true,
            fillColor: cardBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: teal,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String text,
    required VoidCallback onTap,
    required Color color,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    final initialized = _boxData?['initialized'] == true;
    final productWeight = _toInt(_boxData?['productWeightRaw']);
    final emptyRaw = _toInt(_boxData?['emptyRaw']);
    final lastRaw = _toInt(_boxData?['lastWeightRaw']);
    final quantity = _toInt(_boxData?['quantity']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: initialized ? success : warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                initialized ? 'Cutie inițializată' : 'Cutie neinițializată',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('Produs', _productData?['name']?.toString() ?? _boxData?['productName']?.toString() ?? '-'),
          _infoRow('Cantitate', '$quantity buc'),
          _infoRow('Empty raw', '$emptyRaw'),
          _infoRow('Greutate produs raw', '$productWeight'),
          _infoRow('Raw curent', '$lastRaw'),
          _infoRow('Cod QR', _boxData?['qrCode']?.toString() ?? _selectedBox),
        ],
      ),
    );
  }

  Widget _qrCard() {
    final initialized = _boxData?['initialized'] == true;
    final qrValue = _boxData?['qrCode']?.toString() ?? _selectedBox;

    if (!initialized) {
      return const SizedBox();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Text(
            'COD QR CUTIE',
            style: TextStyle(
              color: mutedColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: qrValue,
              version: QrVersions.auto,
              size: 190,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            qrValue.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            left,
            style: TextStyle(
              color: mutedColor,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                  'Inițializare cutii',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Tare • produs • praguri • QR',
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: teal,
                strokeWidth: 2,
              ),
            ),
        ],
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Selectare cutie'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: border),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedBox,
                        dropdownColor: cardBg,
                        underline: const SizedBox(),
                        isExpanded: true,
                        style: TextStyle(color: textColor),
                        iconEnabledColor: teal,
                        items: _boxes.map((box) {
                          return DropdownMenuItem(
                            value: box,
                            child: Text(box.toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) async {
                          if (value == null) return;

                          setState(() {
                            _selectedBox = value;
                            _boxData = null;
                            _productData = null;
                          });

                          await _loadBox();
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    _statusCard(),
                    const SizedBox(height: 24),
                    _qrCard(),
                    const SizedBox(height: 24),
                    _sectionTitle('Pas 1'),
                    const SizedBox(height: 10),
                    _actionButton(
                      text: 'Tare / Salvează cutie goală',
                      onTap: _tareBox,
                      color: midBlue,
                      icon: Icons.scale_rounded,
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Pas 2'),
                    const SizedBox(height: 10),
                    _actionButton(
                      text: 'Salvează greutate produs',
                      onTap: _saveOneProduct,
                      color: success,
                      icon: Icons.inventory_2_rounded,
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Pas 3'),
                    const SizedBox(height: 14),
                    _input(
                      label: 'Nume produs',
                      controller: _productController,
                    ),
                    const SizedBox(height: 16),
                    _input(
                      label: 'Stoc maxim',
                      controller: _maxStockController,
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _input(
                      label: 'Prag galben',
                      controller: _yellowController,
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    _input(
                      label: 'Prag roșu',
                      controller: _redController,
                      type: TextInputType.number,
                    ),
                    const SizedBox(height: 28),
                    _actionButton(
                      text: 'Salvează configurația',
                      onTap: _saveConfig,
                      color: warning,
                      icon: Icons.save_rounded,
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}