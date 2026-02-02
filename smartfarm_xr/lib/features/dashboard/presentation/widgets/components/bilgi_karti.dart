import 'package:flutter/material.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';
import 'package:smartfarm_xr/core/constants/app_text_styles.dart';

/// Bilgi Kartı Widget'ı
/// Sol panelde sistem durumu bilgilerini gösterir
class BilgiKarti extends StatelessWidget {
  final String baslik;
  final String deger;
  final Color renk;
  final Color renkDark;
  final IconData ikon;
  final VoidCallback? onTap;

  const BilgiKarti({
    super.key,
    required this.baslik,
    required this.deger,
    required this.renk,
    required this.renkDark,
    required this.ikon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [renk, renkDark],
          ),
          borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  ikon,
                  color: AppColors.notrBeyaz,
                  size: AppSpacing.iconSize,
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.notrBeyaz.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(AppSpacing.buttonBorderRadius),
                  ),
                  child: Text(
                    deger,
                    style: AppTextStyles.cardValue,
                  ),
                ),
              ],
            ),
            SizedBox(height: AppSpacing.md),
            Text(
              baslik,
              style: AppTextStyles.cardTitle,
            ),
          ],
        ),
      ),
    );
  }
}
