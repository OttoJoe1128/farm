import 'package:flutter/material.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';
import 'components/bilgi_karti.dart';

/// Sol Panel - Bilgi Kartları
/// Toprak nemi, su seviyesi, enerji üretimi/tüketimi, hava sıcaklığı
class SolPanel extends StatelessWidget {
  const SolPanel({super.key});

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
            child: Text(
              'Sistem Durumu',
              style: AppTextStyles.headingMedium,
            ),
          ),
          
          // Bilgi Kartları
          Expanded(
            child: ListView(
              children: [
                // Toprak Nemi Kartı
                BilgiKarti(
                  baslik: 'TOPRAK NEMİ',
                  deger: '%45',
                  renk: AppColors.kartToprak,
                  renkDark: AppColors.kartToprakDark,
                  ikon: Icons.eco,
                  onTap: () {
                    // TODO: Detay sayfasına git
                  },
                ),
                
                SizedBox(height: AppSpacing.panelSpacing),
                
                // Su Seviyesi Kartı
                BilgiKarti(
                  baslik: 'SU SEVİYESİ',
                  deger: '%70',
                  renk: AppColors.kartSu,
                  renkDark: AppColors.kartSuDark,
                  ikon: Icons.water_drop,
                  onTap: () {
                    // TODO: Detay sayfasına git
                  },
                ),
                
                SizedBox(height: AppSpacing.panelSpacing),
                
                // Enerji Üretimi Kartı
                BilgiKarti(
                  baslik: 'ENERJİ ÜRETİMİ',
                  deger: '5 KW',
                  renk: AppColors.kartEnerjiUretim,
                  renkDark: AppColors.kartEnerjiUretimDark,
                  ikon: Icons.solar_power,
                  onTap: () {
                    // TODO: Detay sayfasına git
                  },
                ),
                
                SizedBox(height: AppSpacing.panelSpacing),
                
                // Enerji Tüketimi Kartı
                BilgiKarti(
                  baslik: 'ENERJİ TÜKETİMİ',
                  deger: '3 KW',
                  renk: AppColors.kartEnerjiTuketim,
                  renkDark: AppColors.kartEnerjiTuketimDark,
                  ikon: Icons.power,
                  onTap: () {
                    // TODO: Detay sayfasına git
                  },
                ),
                
                SizedBox(height: AppSpacing.panelSpacing),
                
                // Hava Sıcaklığı Kartı
                BilgiKarti(
                  baslik: 'HAVA SICAKLIĞI',
                  deger: '22 °C',
                  renk: AppColors.kartHava,
                  renkDark: AppColors.kartHavaDark,
                  ikon: Icons.thermostat,
                  onTap: () {
                    // TODO: Detay sayfasına git
                  },
                ),
              ],
            ),
          ),
          
          // Alt Bilgi
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppColors.info,
                  size: 16,
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Son güncelleme: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.caption,
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
