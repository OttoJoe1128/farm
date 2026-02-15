import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'kullanici_yonetimi_sayfasi.dart';
import 'ciftlik_yonetimi_sayfasi.dart';
import 'islem_gecmisi_sayfasi.dart';

/// Admin Panel Ana Sayfasi
class AdminPaneliSayfasi extends StatefulWidget {
  final AuthProvider authProvider;

  const AdminPaneliSayfasi({
    super.key,
    required this.authProvider,
  });

  @override
  State<AdminPaneliSayfasi> createState() => _AdminPaneliSayfasiState();
}

class _AdminPaneliSayfasiState extends State<AdminPaneliSayfasi> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWideScreen = screenWidth > 800;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings, size: 18, color: Colors.redAccent),
                const SizedBox(width: 6),
                Text(
                  widget.authProvider.state.user?.username ?? 'Admin',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
      body: isWideScreen ? _buildWideLayout() : _buildNarrowLayout(),
      bottomNavigationBar: isWideScreen
          ? null
          : NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: 'Kullanicilar',
                ),
                NavigationDestination(
                  icon: Icon(Icons.agriculture_outlined),
                  selectedIcon: Icon(Icons.agriculture),
                  label: 'Ciftlikler',
                ),
                NavigationDestination(
                  icon: Icon(Icons.history_outlined),
                  selectedIcon: Icon(Icons.history),
                  label: 'Gecmis',
                ),
              ],
            ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        NavigationRail(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          labelType: NavigationRailLabelType.all,
          backgroundColor: AppColors.backgroundSecondary,
          destinations: const [
            NavigationRailDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: Text('Kullanicilar'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.agriculture_outlined),
              selectedIcon: Icon(Icons.agriculture),
              label: Text('Ciftlikler'),
            ),
            NavigationRailDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: Text('Gecmis'),
            ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: _buildSelectedPage()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return _buildSelectedPage();
  }

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return const KullaniciYonetimiSayfasi();
      case 1:
        return const CiftlikYonetimiSayfasi();
      case 2:
        return const IslemGecmisiSayfasi();
      default:
        return const KullaniciYonetimiSayfasi();
    }
  }
}
