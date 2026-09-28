import 'package:flutter/material.dart';
import 'app_settings.dart';

class AppColors {
  static const darkBlue = Color(0xFF061E29);
  static const midBlue = Color(0xFF1D546D);
  static const teal = Color(0xFF5F9598);
  static const light = Color(0xFFF3F4F4);
  static const danger = Color(0xFFE05C5C);
  static const success = Color(0xFF4CAF82);
  static const warning = Color(0xFFE8A44A);
}

class MenuItem {
  final String id;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final String route;

  const MenuItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.route,
  });
}

const menuItems = [
  MenuItem(
    id: 'qr',
    icon: Icons.qr_code_scanner_rounded,
    label: 'Scanează QR',
    sublabel: 'Identifică cutia',
    color: AppColors.teal,
    route: '/qr-scan',
  ),
  MenuItem(
    id: 'box-init',
    icon: Icons.tune_rounded,
    label: 'Inițializare cutii',
    sublabel: 'Tare și produs',
    color: AppColors.success,
    route: '/box-init',
  ),
  MenuItem(
    id: 'critical',
    icon: Icons.warning_amber_rounded,
    label: 'Stoc Critic',
    sublabel: 'Produse de comandat',
    color: AppColors.danger,
    route: '/critical-stock',
  ),
  MenuItem(
    id: 'order',
    icon: Icons.add_shopping_cart_rounded,
    label: 'Creează Comandă',
    sublabel: 'Comandă nouă',
    color: AppColors.midBlue,
    route: '/create-order',
  ),
  MenuItem(
    id: 'history',
    icon: Icons.history_rounded,
    label: 'Comenzi Anterioare',
    sublabel: 'Istoric angajați',
    color: AppColors.midBlue,
    route: '/previous-orders',
  ),
  MenuItem(
    id: 'search',
    icon: Icons.search_rounded,
    label: 'Caută Produs',
    sublabel: 'Cod, cutie, detalii',
    color: AppColors.teal,
    route: '/search-products',
  ),
  MenuItem(
    id: 'analytics',
    icon: Icons.bar_chart_rounded,
    label: 'Analytics',
    sublabel: 'Grafice & statistici',
    color: AppColors.warning,
    route: '/analytics',
  ),
  MenuItem(
    id: 'ai-insights',
    icon: Icons.auto_awesome_rounded,
    label: 'AI Insights',
    sublabel: 'Predicții & recomandări',
    color: AppColors.teal,
    route: '/ai-insights',
  ),
  MenuItem(
    id: 'ai-assistant',
    icon: Icons.smart_toy_rounded,
    label: 'AI Assistant',
    sublabel: 'Copilot depozit',
    color: AppColors.teal,
    route: '/ai-assistant',
  ),
];

class HomeScreen extends StatefulWidget {
  final String userName;
  final String userRole;

  const HomeScreen({
    super.key,
    this.userName = 'Denisa Popescu',
    this.userRole = 'Angajat · Depozit',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool get _darkMode => AppSettings.instance.darkMode;

  String get _firstName => widget.userName.split(' ').first;

  String get _initials {
    final parts = widget.userName.trim().split(' ');
    return parts
        .take(2)
        .map((n) => n.isNotEmpty ? n[0].toUpperCase() : '')
        .join();
  }

  Color get _bg => _darkMode ? AppColors.darkBlue : AppColors.light;
  Color get _cardBg => _darkMode ? const Color(0xFF0F3244) : Colors.white;
  Color get _headerBg => _darkMode ? const Color(0xFF08263A) : Colors.white;
  Color get _drawerBg => _darkMode ? const Color(0xFF0A2838) : Colors.white;

  Color get _textColor => _darkMode ? AppColors.light : AppColors.darkBlue;

  Color get _mutedColor => _darkMode
      ? AppColors.light.withOpacity(0.55)
      : AppColors.darkBlue.withOpacity(0.48);

  Color get _border => _darkMode
      ? AppColors.teal.withOpacity(0.20)
      : AppColors.midBlue.withOpacity(0.13);

  void _navigate(String route) {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    Navigator.pushNamed(context, route);
  }

  void _logout() {
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.of(context).pop();
    }

    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: _bg,
          drawer: _buildDrawer(),
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
                        _sectionLabel('Meniu principal'),
                        const SizedBox(height: 14),
                        _buildGrid(),
                        const SizedBox(height: 24),
                        _buildEsp32StatusBar(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: _headerBg,
        border: Border(
          bottom: BorderSide(color: _border, width: 1),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _burgerLine(18),
                  _burgerLine(14),
                  _burgerLine(10),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello,',
                  style: TextStyle(
                    color: _mutedColor,
                    fontSize: 13,
                  ),
                ),
                Text(
                  '$_firstName 👋',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          CircleAvatar(
            radius: 21,
            backgroundColor: AppColors.teal,
            child: Text(
              _initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _burgerLine(double width) {
    return Container(
      width: width,
      height: 2,
      decoration: BoxDecoration(
        color: _textColor,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: _mutedColor,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width > 700 ? 3 : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: menuItems.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.90,
          ),
          itemBuilder: (_, i) {
            return _MenuCard(
              item: menuItems[i],
              cardBg: _cardBg,
              border: _border,
              textColor: _textColor,
              mutedColor: _mutedColor,
              onTap: () => _navigate(menuItems[i].route),
            );
          },
        );
      },
    );
  }

  Widget _buildEsp32StatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Status stoc ESP32',
              style: TextStyle(
                color: _mutedColor,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          _statusDot(AppColors.success, 'OK'),
          const SizedBox(width: 12),
          _statusDot(AppColors.warning, 'Scăzut'),
          const SizedBox(width: 12),
          _statusDot(AppColors.danger, 'Critic'),
        ],
      ),
    );
  }

  Widget _statusDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.45),
                blurRadius: 5,
              ),
            ],
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: _mutedColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: _drawerBg,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _border),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppColors.teal,
                    child: Text(
                      _initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.userName,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.userRole,
                    style: TextStyle(
                      color: _mutedColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _drawerItem(
              icon: Icons.home_rounded,
              label: 'Dashboard',
              onTap: () {
                if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
                  Navigator.of(context).pop();
                }
              },
            ),
            _drawerItem(
              icon: Icons.tune_rounded,
              label: 'Inițializare cutii',
              onTap: () => _navigate('/box-init'),
            ),
            _drawerItem(
              icon: Icons.history_rounded,
              label: 'Comenzile mele',
              onTap: () => _navigate('/my-orders'),
            ),
            _drawerItem(
              icon: Icons.search_rounded,
              label: 'Caută produs',
              onTap: () => _navigate('/search-products'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ListTile(
                leading: Icon(
                  _darkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: _mutedColor,
                  size: 22,
                ),
                title: Text(
                  'Dark Mode',
                  style: TextStyle(
                    color: _textColor,
                    fontSize: 15,
                  ),
                ),
                trailing: Switch(
                  value: _darkMode,
                  onChanged: (v) async {
                    await AppSettings.instance.setDarkMode(v);
                  },
                  activeColor: AppColors.teal,
                  inactiveThumbColor: Colors.grey,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.danger,
                  size: 22,
                ),
                title: const Text(
                  'Log Out',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: _logout,
                tileColor: AppColors.danger.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Icon(
          icon,
          color: _mutedColor,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: _textColor,
            fontSize: 15,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: _mutedColor,
          size: 20,
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _MenuCard extends StatefulWidget {
  final MenuItem item;
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _MenuCard({
    required this.item,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _scale = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: widget.cardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: widget.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 4,
                color: widget.item.color,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: widget.item.color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          widget.item.icon,
                          color: widget.item.color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.sublabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.mutedColor,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: widget.item.color,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}