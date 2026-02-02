import 'package:flutter/material.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';
import 'package:smartfarm_xr/core/constants/app_enums.dart';

/// Uyarı Kartı Widget'ı
/// Sağ panelde kritik durumlar ve aksiyon önerilerini gösterir
class UyariKarti extends StatelessWidget {
  final String baslik;
  final String mesaj;
  final UyariSeviyesi seviye;
  final Color renk;
  final Color renkDark;
  final IconData ikon;
  final VoidCallback? onAksiyon;

  const UyariKarti({
    super.key,
    required this.baslik,
    required this.mesaj,
    required this.seviye,
    required this.renk,
    required this.renkDark,
    required this.ikon,
    this.onAksiyon,
  });

  IconData _getSeviyeIcon() {
    switch (seviye) {
      case UyariSeviyesi.critical:
        return Icons.error;
      case UyariSeviyesi.warning:
        return Icons.warning;
      case UyariSeviyesi.info:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [renk, renkDark],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
        border: Border.all(
          color: renk.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: renk.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSeviyeIcon(),
                color: AppColors.notrBeyaz,
                size: 20,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  baslik,
                  style: AppTextStyles.alertTitle,
                ),
              ),
              Icon(
                ikon,
                color: AppColors.notrBeyaz,
                size: 24,
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            mesaj,
            style: AppTextStyles.alertMessage,
          ),
          if (onAksiyon != null) ...[
            SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAksiyon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.notrBeyaz.withOpacity(0.2),
                  foregroundColor: AppColors.notrBeyaz,
                ),
                child: const Text('Aksiyon Al'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
