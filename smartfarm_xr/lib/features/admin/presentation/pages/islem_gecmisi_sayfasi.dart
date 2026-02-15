import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/admin_service.dart';

/// Islem Gecmisi Sayfasi - Audit log goruntuleme
class IslemGecmisiSayfasi extends StatefulWidget {
  const IslemGecmisiSayfasi({super.key});

  @override
  State<IslemGecmisiSayfasi> createState() => _IslemGecmisiSayfasiState();
}

class _IslemGecmisiSayfasiState extends State<IslemGecmisiSayfasi> {
  final AdminService _adminService = AdminService();
  final TextEditingController _userIdController = TextEditingController();
  List<Map<String, dynamic>> _loglar = [];
  int _toplamLog = 0;
  int _mevcutSayfa = 1;
  bool _yukleniyor = false;
  String? _hata;
  bool _aramaDurumu = false;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _logYukle(String userId) async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
      _aramaDurumu = true;
    });
    try {
      final Map<String, dynamic> response = await _adminService.fetchAuditLog(
        userId,
        page: _mevcutSayfa,
      );
      final List<dynamic> logs = response['logs'] as List<dynamic>? ?? [];
      setState(() {
        _loglar = logs.cast<Map<String, dynamic>>();
        _toplamLog = response['total'] as int? ?? 0;
        _yukleniyor = false;
      });
    } catch (err) {
      setState(() {
        _hata = 'Islem gecmisi yuklenirken hata: $err';
        _yukleniyor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Islem Gecmisi',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Kullanici ID ile arama
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _userIdController,
                  decoration: const InputDecoration(
                    hintText: 'Kullanici UUID girin...',
                    prefixIcon: Icon(Icons.person_search),
                    isDense: true,
                  ),
                  onSubmitted: (String value) {
                    if (value.trim().isNotEmpty) {
                      _mevcutSayfa = 1;
                      _logYukle(value.trim());
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  if (_userIdController.text.trim().isNotEmpty) {
                    _mevcutSayfa = 1;
                    _logYukle(_userIdController.text.trim());
                  }
                },
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Ara'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Not: Islem gecmisi kullanici ID ile sorgulanir. Kullanicilar sayfasindan UUID kopyalayabilirsiniz.',
            style: TextStyle(fontSize: 11, color: AppColors.notrGri500),
          ),
          const SizedBox(height: 16),
          // Icerik
          Expanded(
            child: !_aramaDurumu
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: AppColors.notrGri700),
                        SizedBox(height: 12),
                        Text(
                          'Bir kullanicinin islem gecmisini gormek icin\nkullanici UUID girin',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.notrGri500),
                        ),
                      ],
                    ),
                  )
                : _yukleniyor
                    ? const Center(child: CircularProgressIndicator())
                    : _hata != null
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                                const SizedBox(height: 12),
                                Text(_hata!, style: const TextStyle(color: AppColors.error)),
                              ],
                            ),
                          )
                        : _loglar.isEmpty
                            ? const Center(child: Text('Bu kullanici icin islem kaydı bulunamadi'))
                            : ListView.builder(
                                itemCount: _loglar.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final Map<String, dynamic> log = _loglar[index];
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: _islemRengi(log['action'] as String? ?? '').withValues(alpha: 0.2),
                                        child: Icon(
                                          _islemIkonu(log['action'] as String? ?? ''),
                                          size: 18,
                                          color: _islemRengi(log['action'] as String? ?? ''),
                                        ),
                                      ),
                                      title: Text(
                                        log['action'] as String? ?? '-',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (log['entity_type'] != null)
                                            Text(
                                              '${log['entity_type']} ${log['entity_id'] ?? ''}',
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                          if (log['details'] != null)
                                            Text(
                                              log['details'].toString(),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 10, color: AppColors.notrGri500),
                                            ),
                                        ],
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _formatDate(log['created_at'] as String?),
                                            style: const TextStyle(fontSize: 11, color: AppColors.notrGri500),
                                          ),
                                          if (log['ip_address'] != null)
                                            Text(
                                              log['ip_address'] as String,
                                              style: const TextStyle(fontSize: 10, color: AppColors.notrGri600),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
          ),
          // Sayfalama
          if (_aramaDurumu && _toplamLog > 20)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _mevcutSayfa > 1
                        ? () {
                            setState(() {
                              _mevcutSayfa--;
                            });
                            _logYukle(_userIdController.text.trim());
                          }
                        : null,
                  ),
                  Text('Sayfa $_mevcutSayfa / ${(_toplamLog / 20).ceil()}'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _loglar.length == 20
                        ? () {
                            setState(() {
                              _mevcutSayfa++;
                            });
                            _logYukle(_userIdController.text.trim());
                          }
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _islemRengi(String action) {
    if (action.contains('login') || action.contains('register')) return Colors.blueAccent;
    if (action.contains('logout')) return Colors.orangeAccent;
    if (action.contains('role')) return Colors.purpleAccent;
    if (action.contains('deactivate') || action.contains('delete')) return Colors.redAccent;
    if (action.contains('farm')) return Colors.greenAccent;
    return AppColors.notrGri500;
  }

  IconData _islemIkonu(String action) {
    if (action.contains('login')) return Icons.login;
    if (action.contains('register')) return Icons.person_add;
    if (action.contains('logout')) return Icons.logout;
    if (action.contains('role')) return Icons.admin_panel_settings;
    if (action.contains('deactivate')) return Icons.person_off;
    if (action.contains('farm')) return Icons.agriculture;
    if (action.contains('update')) return Icons.edit;
    return Icons.history;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final DateTime date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }
}
