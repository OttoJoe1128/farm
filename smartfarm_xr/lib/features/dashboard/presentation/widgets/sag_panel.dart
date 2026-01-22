import 'package:flutter/material.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';
import 'package:smartfarm_xr/core/constants/app_enums.dart';
import 'components/uyari_karti.dart';

/// Sağ Panel - Uyarı Kartları
/// Kritik durumlar ve aksiyon önerileri
class SagPanel extends StatelessWidget {
  const SagPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel Başlığı
          Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.sectionSpacing),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: AppColors.warning,
                  size: 24,
                ),
                SizedBox(width: AppSpacing.sm),
                Text(
                  'Uyarılar & Aksiyonlar',
                  style: AppTextStyles.headingMedium,
                ),
              ],
            ),
          ),
          
          // Uyarı Kartları
          Expanded(
            child: ListView(
              children: [
                // Nem Kritik Uyarısı
                UyariKarti(
                  baslik: 'NEM KRİTİK %30',
                  mesaj: 'Toprak nemi kritik seviyede. Sulama sistemi aktif edilmeli.',
                  seviye: UyariSeviyesi.critical,
                  renk: AppColors.uyariNemKritik,
                  renkDark: AppColors.uyariNemKritikDark,
                  ikon: Icons.eco,
                  onAksiyon: () {
                    // TODO: Sulama sistemini aktif et
                  },
                ),
                
                SizedBox(height: AppSpacing.panelSpacing),
                
                // Su Deposu Uyarısı
                UyariKarti(
                  baslik: 'SU DEPOSU',
                  mesaj: 'Su deposu dolmak üzere. Pompa durdurulmalı.',
                  seviye: UyariSeviyesi.warning,
                  renk: AppColors.uyariSuDeposu,
                  renkDark: AppColors.uyariSuDeposuDark,
                  ikon: Icons.water_drop,
                  onAksiyon: () {
                    // TODO: Pompayı durdur
                  },
                ),
                
                SizedBox(height: AppSpacing.panelSpacing),
                
                // Enerji Üretimi Uyarısı
                UyariKarti(
                  baslik: 'ENERJİ ÜRETİMİ',
                  mesaj: 'Enerji üretimi %20 azaldı. Solar panel kontrol edilmeli.',
                  seviye: UyariSeviyesi.warning,
                  renk: AppColors.uyariEnerjiAzalma,
                  renkDark: AppColors.uyariEnerjiAzalmaDark,
                  ikon: Icons.solar_power,
                  onAksiyon: () {
                    // TODO: Solar panel kontrolü
                  },
                ),
                
                SizedBox(height: AppSpacing.panelSpacing),
                
                // Gübre Zamanı Uyarısı
                UyariKarti(
                  baslik: 'GÜBRE ZAMANI',
                  mesaj: 'Toprak analizi yapıldı. Gübreleme zamanı geldi.',
                  seviye: UyariSeviyesi.info,
                  renk: AppColors.uyariGubreZamani,
                  renkDark: AppColors.uyariGubreZamaniDark,
                  ikon: Icons.eco,
                  onAksiyon: () {
                    // TODO: Gübreleme planı
                  },
                ),
                
                SizedBox(height: AppSpacing.panelSpacing),
                
                // Hayvan Besleme Uyarısı
                UyariKarti(
                  baslik: 'HAYVAN BESLEME',
                  mesaj: 'Hayvan besleme zamanı. Yem makinesi çalıştırılmalı.',
                  seviye: UyariSeviyesi.info,
                  renk: AppColors.uyariHayvanBesleme,
                  renkDark: AppColors.uyariHayvanBeslemeDark,
                  ikon: Icons.pets,
                  onAksiyon: () {
                    // TODO: Yem makinesini çalıştır
                  },
                ),
              ],
            ),
          ),
          
          // Alt Bilgi
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard.withOpacity(0.8),
              borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
              border: Border.all(
                color: AppColors.warning.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.warning,
                  size: 16,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '5 aktif uyarı • 2 kritik durum',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
