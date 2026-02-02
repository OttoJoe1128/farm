import 'package:flutter/material.dart';
import 'package:smartfarm_xr/core/constants/app_colors.dart';
import 'package:smartfarm_xr/core/constants/app_spacing.dart';

/// Sürüklenebilir Panel Widget'ı
/// Harita üzerinde sürüklenebilir kontrol panelleri için
class DraggablePanel extends StatefulWidget {
  final String title;
  final Offset initialPosition;
  final double width;
  final VoidCallback? onClose;
  final Widget child;

  const DraggablePanel({
    super.key,
    required this.title,
    required this.initialPosition,
    required this.width,
    this.onClose,
    required this.child,
  });

  @override
  State<DraggablePanel> createState() => _DraggablePanelState();
}

class _DraggablePanelState extends State<DraggablePanel> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initialPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position += details.delta;
          });
        },
        child: Container(
          width: widget.width,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height - _position.dy - 20,
          ),
          decoration: BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.circular(AppSpacing.cardBorderRadius),
            border: Border.all(
              color: AppColors.notrGri600,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Başlık çubuğu
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppSpacing.cardBorderRadius),
                    topRight: Radius.circular(AppSpacing.cardBorderRadius),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: AppColors.notrBeyaz,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (widget.onClose != null)
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.notrBeyaz,
                          size: 20,
                        ),
                        onPressed: widget.onClose,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),
              // İçerik
              Flexible(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: widget.child,
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
