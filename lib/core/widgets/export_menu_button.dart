import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

enum AppExportFormat { pdf, excel }

class AppExportMenuButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onPdf;
  final VoidCallback onExcel;

  const AppExportMenuButton({
    super.key,
    required this.enabled,
    required this.onPdf,
    required this.onExcel,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return PopupMenuButton<AppExportFormat>(
      enabled: enabled,
      tooltip: 'Exporter',
      onSelected: (format) {
        switch (format) {
          case AppExportFormat.pdf:
            onPdf();
            break;
          case AppExportFormat.excel:
            onExcel();
            break;
        }
      },
      position: PopupMenuPosition.under,
      offset: const Offset(0, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: AppExportFormat.pdf,
          child: _ExportMenuItem(
            icon: Icons.picture_as_pdf_rounded,
            color: Color(0xFFD14343),
            title: 'Exporter en PDF',
            subtitle: 'Aperçu, impression ou téléchargement',
          ),
        ),
        PopupMenuItem(
          value: AppExportFormat.excel,
          child: _ExportMenuItem(
            icon: Icons.table_view_rounded,
            color: Color(0xFF18794E),
            title: 'Exporter en Excel',
            subtitle: 'Classeur modifiable au format XLSX',
          ),
        ),
      ],
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.45,
        duration: const Duration(milliseconds: 160),
        child: Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.download_rounded,
                color: Colors.white,
                size: 19,
              ),
              if (!compact) ...[
                const SizedBox(width: 7),
                const Text(
                  'Exporter',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ExportMenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _ExportMenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.grisText,
                    fontSize: 10,
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

void showExportSuccess(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF18794E),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
