import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../admin/presentation/pages/admin_paneli_sayfasi.dart';
import '../../data/models/user_model.dart';
import '../providers/auth_provider.dart';

/// Profil Sayfasi - Kullanici profil bilgileri ve cikis
class ProfilSayfasi extends StatelessWidget {
  final AuthProvider authProvider;
  final VoidCallback onLogout;

  const ProfilSayfasi({
    super.key,
    required this.authProvider,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil'),
      ),
      body: ListenableBuilder(
        listenable: authProvider,
        builder: (BuildContext context, Widget? child) {
          final UserBrief? user = authProvider.state.user;
          if (user == null) {
            return const Center(child: Text('Kullanici bilgisi bulunamadi'));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    _buildAvatar(user),
                    const SizedBox(height: 24),
                    _buildInfoCard(user),
                    const SizedBox(height: 24),
                    // Admin panel butonu (sadece admin rolune goruntulenir)
                    if (authProvider.state.isAdmin)
                      _buildAdminPanelButton(context),
                    if (authProvider.state.isAdmin)
                      const SizedBox(height: 16),
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAvatar(UserBrief user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppColors.gridMor.withValues(alpha: 0.3),
          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null
              ? Text(
                  (user.fullName ?? user.username)[0].toUpperCase(),
                  style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          user.fullName ?? user.username,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '@${user.username}',
          style: const TextStyle(color: AppColors.notrGri500, fontSize: 14),
        ),
        const SizedBox(height: 8),
        _buildRoleBadge(user.role),
      ],
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    String displayName;
    switch (role) {
      case 'admin':
        badgeColor = Colors.redAccent;
        displayName = 'Admin';
        break;
      case 'yonetici':
        badgeColor = Colors.blue;
        displayName = 'Yonetici';
        break;
      case 'calisan':
        badgeColor = Colors.green;
        displayName = 'Calisan';
        break;
      case 'tarimci':
        badgeColor = Colors.amber;
        displayName = 'Tarimci';
        break;
      default:
        badgeColor = AppColors.notrGri600;
        displayName = 'Izleyici';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        displayName,
        style: TextStyle(color: badgeColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildInfoCard(UserBrief user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(Icons.email_outlined, 'E-posta', user.email),
            const Divider(),
            _buildInfoRow(Icons.person_outline, 'Kullanici Adi', user.username),
            if (user.fullName != null) ...[
              const Divider(),
              _buildInfoRow(Icons.badge_outlined, 'Tam Ad', user.fullName!),
            ],
            const Divider(),
            _buildInfoRow(Icons.shield_outlined, 'Rol', _roleDisplayName(user.role)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.notrGri500),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: AppColors.notrGri500, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 15),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _roleDisplayName(String role) {
    switch (role) {
      case 'admin': return 'Sistem Yoneticisi';
      case 'yonetici': return 'Ciftlik Yoneticisi';
      case 'calisan': return 'Calisan';
      case 'tarimci': return 'Tarimci / Uzman';
      case 'izleyici': return 'Izleyici';
      default: return role;
    }
  }

  Widget _buildAdminPanelButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) => AdminPaneliSayfasi(
                authProvider: authProvider,
              ),
            ),
          );
        },
        icon: const Icon(Icons.admin_panel_settings),
        label: const Text('Admin Paneli'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () async {
          final bool? confirm = await showDialog<bool>(
            context: context,
            builder: (BuildContext context) => AlertDialog(
              title: const Text('Cikis Yap'),
              content: const Text('Oturumunuzu kapatmak istediginize emin misiniz?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Iptal'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                  child: const Text('Cikis Yap'),
                ),
              ],
            ),
          );
          if (confirm == true) {
            await authProvider.logout();
            onLogout();
          }
        },
        icon: const Icon(Icons.logout, color: AppColors.error),
        label: const Text('Cikis Yap', style: TextStyle(color: AppColors.error)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}
