import 'package:flutter/material.dart';
import 'api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading       = false;
  String? _errorMessage;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Azure AD / SQL login ───────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    try {
      // TODO: înlocuiește cu apelul real către Azure SQL
      // Exemplu real:
      // final user = await AzureAuthService.login(
      //   email:    _emailController.text.trim(),
      //   password: _passwordController.text,
      // );
      // if (user == null) throw Exception('invalid credentials');

      final email    = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      // Încearcă API real (Supabase)
      // Dacă nu e configurat, cade pe userii de test
      Map<String, dynamic>? apiUser;
      try {
        apiUser = await ApiService.login(email, password);
      } catch (_) {
        apiUser = null;
      }

      // Useri de test (fallback când API nu e configurat încă)
      final testUsers = {
        'admin@stockiq.ro':  {'password': 'admin123',  'name': 'Admin StockIQ',  'role': 'Administrator'},
        'denisa@stockiq.ro': {'password': 'denisa123', 'name': 'Denisa Popescu', 'role': 'Angajat · Depozit'},
        'mirel@stockiq.ro':  {'password': 'mirel123',  'name': 'Mirel Marcu',    'role': 'Angajat · Depozit'},
      };

      String? userName;
      String? userRole;
      if (apiUser != null) {
        // Login prin Supabase reușit
        userName = apiUser['full_name'] as String?;
        userRole = apiUser['role'] as String?;
      } else {
        // Fallback useri de test
        final found = testUsers[email];
        if (found == null || found['password'] != password) {
          throw Exception('invalid credentials');
        }
        userName = found['name'];
        userRole = found['role'];
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/home',
        arguments: {
          'userName': userName ?? email,
          'userRole': userRole ?? 'Angajat · Depozit',
        },
      );
    } catch (e) {
      setState(() => _errorMessage = 'Email sau parolă incorectă.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F4),
      body: Stack(
        children: [
          // ── Background decorativ cu cutii ─────────────────────────────────
          const _WarehouseBackground(),

          // ── Card centrat ──────────────────────────────────────────────────
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D546D).withOpacity(0.10),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo
                          const _StockIQLogo(),
                          const SizedBox(height: 10),

                          // App name
                          const Text(
                            'StockIQ',
                            style: TextStyle(
                              color: Color(0xFF061E29),
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Tagline
                          const Text(
                            'Scan. Track. Manage.',
                            style: TextStyle(
                              color: Color(0xFF5F9598),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Email field
                          _InputField(
                            controller: _emailController,
                            hint: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Introdu emailul';
                              if (!v.contains('@')) return 'Email invalid';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password field
                          _InputField(
                            controller: _passwordController,
                            hint: 'Password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF5F9598),
                                size: 20,
                              ),
                              onPressed: () => setState(
                                      () => _obscurePassword = !_obscurePassword),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Introdu parola';
                              if (v.length < 4) return 'Prea scurtă';
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),

                          // Error message
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE05C5C).withOpacity(0.10),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: Color(0xFFE05C5C), size: 16),
                                  const SizedBox(width: 8),
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                        color: Color(0xFFE05C5C), fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // LOGIN button
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D546D),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                const Color(0xFF1D546D).withOpacity(0.6),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                                  : const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo SVG-style desenat cu CustomPainter
// ─────────────────────────────────────────────────────────────────────────────
class _StockIQLogo extends StatelessWidget {
  const _StockIQLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Culorile cubului
    final paintDark = Paint()..color = const Color(0xFF1D546D);
    final paintMid  = Paint()..color = const Color(0xFF5F9598);
    final paintGlass= Paint()
      ..color = const Color(0xFF5F9598).withOpacity(0.35);
    final paintLine = Paint()
      ..color = const Color(0xFF061E29).withOpacity(0.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final paintDot  = Paint()..color = const Color(0xFF5F9598);
    final paintDotD = Paint()..color = const Color(0xFF061E29);

    // Cub izometric simplificat
    // Fata stanga (dark)
    final leftFace = Path()
      ..moveTo(cx, cy - 18)
      ..lineTo(cx - 22, cy - 6)
      ..lineTo(cx - 22, cy + 14)
      ..lineTo(cx, cy + 2)
      ..close();
    canvas.drawPath(leftFace, paintDark);

    // Fata dreapta (teal)
    final rightFace = Path()
      ..moveTo(cx, cy - 18)
      ..lineTo(cx + 22, cy - 6)
      ..lineTo(cx + 22, cy + 14)
      ..lineTo(cx, cy + 2)
      ..close();
    canvas.drawPath(rightFace, paintMid);

    // Fata sus (glass)
    final topFace = Path()
      ..moveTo(cx, cy - 28)
      ..lineTo(cx - 22, cy - 16)
      ..lineTo(cx, cy - 4)
      ..lineTo(cx + 22, cy - 16)
      ..close();
    canvas.drawPath(topFace, paintGlass);

    // Contur cub
    canvas.drawPath(leftFace, paintLine);
    canvas.drawPath(rightFace, paintLine);
    canvas.drawPath(topFace, paintLine);

    // Noduri si linii decorative (reteaua din logo)
    final nodes = [
      Offset(cx - 32, cy - 22),
      Offset(cx + 34, cy - 20),
      Offset(cx - 30, cy + 22),
      Offset(cx + 32, cy + 20),
      Offset(cx, cy - 38),
      Offset(cx - 10, cy + 32),
    ];
    final lineP = Paint()
      ..color = const Color(0xFF5F9598).withOpacity(0.5)
      ..strokeWidth = 0.9;

    // Linii spre noduri
    for (final node in nodes) {
      canvas.drawLine(Offset(cx, cy - 16), node, lineP);
    }

    // Noduri
    for (int i = 0; i < nodes.length; i++) {
      canvas.drawCircle(
        nodes[i], i < 3 ? 3.5 : 2.8,
        i % 2 == 0 ? paintDot : paintDotD,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Input field reutilizabil
// ─────────────────────────────────────────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType = TextInputType.text,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF061E29),
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: const Color(0xFF061E29).withOpacity(0.38),
          fontSize: 15,
        ),
        prefixIcon: Icon(icon, color: const Color(0xFF5F9598), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF3F4F4),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: const Color(0xFF5F9598).withOpacity(0.15),
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Color(0xFF5F9598),
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFFE05C5C), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFFE05C5C), width: 1.5),
        ),
        errorStyle: const TextStyle(color: Color(0xFFE05C5C), fontSize: 12),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background cu cutii desenate (linii subtile)
// ─────────────────────────────────────────────────────────────────────────────
class _WarehouseBackground extends StatelessWidget {
  const _WarehouseBackground();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CustomPaint(painter: _BgPainter()),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF5F9598).withOpacity(0.12)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Cutie stanga
    _drawBox(canvas, paint, Offset(size.width * 0.05, size.height * 0.38),
        60, 50, 20);
    _drawBox(canvas, paint, Offset(size.width * 0.08, size.height * 0.55),
        45, 36, 15);

    // Cutie dreapta
    _drawBox(canvas, paint, Offset(size.width * 0.72, size.height * 0.36),
        65, 52, 22);
    _drawBox(canvas, paint, Offset(size.width * 0.78, size.height * 0.54),
        42, 34, 14);

    // Sageti decorative
    _drawArrow(canvas, paint,
        Offset(size.width * 0.80, size.height * 0.28),
        Offset(size.width * 0.88, size.height * 0.32));
    _drawArrow(canvas, paint,
        Offset(size.width * 0.12, size.height * 0.28),
        Offset(size.width * 0.18, size.height * 0.24));
  }

  void _drawBox(Canvas c, Paint p, Offset o, double w, double h, double d) {
    // Fata frontala
    c.drawRect(Rect.fromLTWH(o.dx, o.dy, w, h), p);
    // Fata sus (perspectiva izometrica simplificata)
    final top = Path()
      ..moveTo(o.dx, o.dy)
      ..lineTo(o.dx + d, o.dy - d * 0.6)
      ..lineTo(o.dx + w + d, o.dy - d * 0.6)
      ..lineTo(o.dx + w, o.dy)
      ..close();
    c.drawPath(top, p);
    // Fata dreapta
    final right = Path()
      ..moveTo(o.dx + w, o.dy)
      ..lineTo(o.dx + w + d, o.dy - d * 0.6)
      ..lineTo(o.dx + w + d, o.dy + h - d * 0.6)
      ..lineTo(o.dx + w, o.dy + h)
      ..close();
    c.drawPath(right, p);
    // Linie mijloc cutie
    c.drawLine(
        Offset(o.dx, o.dy + h * 0.42), Offset(o.dx + w, o.dy + h * 0.42), p);
    c.drawLine(
        Offset(o.dx + w * 0.5, o.dy),
        Offset(o.dx + w * 0.5, o.dy + h * 0.42), p);
  }

  void _drawArrow(Canvas c, Paint p, Offset from, Offset to) {
    c.drawLine(from, to, p);
    const arrowSize = 6.0;
    final angle = (to - from).direction;
    final p1 = Offset(
      to.dx - arrowSize * (0.866 * (to.dx - from.dx).sign + 0.5 * (to.dy - from.dy).sign),
      to.dy - arrowSize * (0.5 * (to.dx - from.dx).sign - 0.866 * (to.dy - from.dy).sign),
    );
    c.drawLine(to, p1, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}