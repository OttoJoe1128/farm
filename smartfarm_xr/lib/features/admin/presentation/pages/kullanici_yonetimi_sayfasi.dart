import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/admin_service.dart';
import '../widgets/kullanici_tablosu.dart';

/// Kullanici Yonetimi Sayfasi
class KullaniciYonetimiSayfasi extends StatefulWidget {
  const KullaniciYonetimiSayfasi({super.key});

  @override
  State<KullaniciYonetimiSayfasi> createState() => _KullaniciYonetimiSayfasiState();
}

class _KullaniciYonetimiSayfasiState extends State<KullaniciYonetimiSayfasi> {
  final AdminService _adminService = AdminService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _kullanicilar = [];
  int _toplamKullanici = 0;
  int _mevcutSayfa = 1;
  String? _rolFiltresi;
  bool _yukleniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _verileriYukle();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _verileriYukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final Map<String, dynamic> response = await _adminService.fetchUsers(
        page: _mevcutSayfa,
        search: _searchController.text.trim().isNotEmpty ? _searchController.text.trim() : null,
        role: _rolFiltresi,
      );
      final List<dynamic> users = response['users'] as List<dynamic>? ?? [];
      setState(() {
        _kullanicilar = users.cast<Map<String, dynamic>>();
        _toplamKullanici = response['total'] as int? ?? 0;
        _yukleniyor = false;
      });
    } catch (err) {
      setState(() {
        _hata = 'Kullanicilar yuklenirken hata: $err';
        _yukleniyor = false;
      });
    }
  }

  Future<void> _rolDegistir(String userId, String newRole) async {
    try {
      await _adminService.updateUserRole(userId, newRole);
      await _verileriYukle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rol basariyla degistirildi'), backgroundColor: Colors.green),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rol degistirme hatasi: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _kullaniciDeaktiveEt(String userId) async {
    final bool? onay = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Kullanici Deaktive Et'),
        content: const Text('Bu kullaniciyi deaktive etmek istediginize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Iptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Deaktive Et'),
          ),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await _adminService.deactivateUser(userId);
      await _verileriYukle();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanici deaktive edildi'), backgroundColor: Colors.orange),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $err'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baslik ve arama
          Row(
            children: [
              const Text(
                'Kullanici Yonetimi',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '$_toplamKullanici kullanici',
                style: const TextStyle(color: AppColors.notrGri500),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Arama ve filtre
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Kullanici ara...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _mevcutSayfa = 1;
                              _verileriYukle();
                            },
                          )
                        : null,
                    isDense: true,
                  ),
                  onSubmitted: (_) {
                    _mevcutSayfa = 1;
                    _verileriYukle();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _rolFiltresi,
                  decoration: const InputDecoration(
                    hintText: 'Rol filtresi',
                    isDense: true,
                  ),
                  dropdownColor: AppColors.backgroundCard,
                  items: const [
                    DropdownMenuItem<String>(value: null, child: Text('Tum Roller')),
                    DropdownMenuItem<String>(value: 'admin', child: Text('Admin')),
                    DropdownMenuItem<String>(value: 'yonetici', child: Text('Yonetici')),
                    DropdownMenuItem<String>(value: 'calisan', child: Text('Calisan')),
                    DropdownMenuItem<String>(value: 'tarimci', child: Text('Tarimci')),
                    DropdownMenuItem<String>(value: 'izleyici', child: Text('Izleyici')),
                  ],
                  onChanged: (String? value) {
                    setState(() {
                      _rolFiltresi = value;
                      _mevcutSayfa = 1;
                    });
                    _verileriYukle();
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Yenile',
                onPressed: _verileriYukle,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Icerik
          Expanded(
            child: _yukleniyor
                ? const Center(child: CircularProgressIndicator())
                : _hata != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                            const SizedBox(height: 12),
                            Text(_hata!, style: const TextStyle(color: AppColors.error)),
                            const SizedBox(height: 12),
                            ElevatedButton(onPressed: _verileriYukle, child: const Text('Tekrar Dene')),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: KullaniciTablosu(
                          kullanicilar: _kullanicilar,
                          onRolDegistir: _rolDegistir,
                          onDeaktiveEt: _kullaniciDeaktiveEt,
                          onDetayGor: (String userId) {
                            // Detay dialog goster
                            _kullaniciDetayGoster(userId);
                          },
                        ),
                      ),
          ),
          // Sayfalama
          if (_toplamKullanici > 20)
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
                            _verileriYukle();
                          }
                        : null,
                  ),
                  Text('Sayfa $_mevcutSayfa'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _kullanicilar.length == 20
                        ? () {
                            setState(() {
                              _mevcutSayfa++;
                            });
                            _verileriYukle();
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

  void _kullaniciDetayGoster(String userId) {
    final Map<String, dynamic>? user = _kullanicilar.cast<Map<String, dynamic>?>().firstWhere(
      (Map<String, dynamic>? u) => u?['id'] == userId,
      orElse: () => null,
    );
    if (user == null) return;
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(user['full_name'] as String? ?? user['username'] as String? ?? 'Kullanici'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detaySatir('Kullanici Adi', '@${user['username']}'),
            _detaySatir('E-posta', user['email'] as String? ?? '-'),
            _detaySatir('Rol', user['role'] as String? ?? '-'),
            _detaySatir('Durum', (user['is_active'] as bool? ?? true) ? 'Aktif' : 'Pasif'),
            _detaySatir('Telefon', user['phone'] as String? ?? '-'),
            _detaySatir('Son Giris', user['last_login_at'] as String? ?? 'Hic'),
            _detaySatir('Kayit Tarihi', user['created_at'] as String? ?? '-'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ],
      ),
    );
  }

  Widget _detaySatir(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text('$label:', style: const TextStyle(color: AppColors.notrGri500, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
