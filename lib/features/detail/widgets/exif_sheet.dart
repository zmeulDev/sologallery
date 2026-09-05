import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_space.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/photo_library_service.dart' show AssetDetail;
import '../../../widgets/app_sheet.dart';
import '../detail_providers.dart';
import '../domain/asset_detail_display.dart';

/// Opens the EXIF/metadata sheet for [assetId] from the detail viewer.
Future<void> showExifSheet(BuildContext context, String assetId) {
  return showAppSheet<void>(
    context,
    builder: (_) => ExifSheet(assetId: assetId),
  );
}

/// Bottom sheet of `photo_manager`-native metadata as a flush-left two-column
/// table (uppercase key, hairline row dividers). Reads [assetDetailProvider];
/// renders explicit loading / error / data states.
class ExifSheet extends ConsumerWidget {
  const ExifSheet({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(assetDetailProvider(assetId));

    return AppSheet(
      label: 'DETAILS',
      child: detail.when(
        loading: () => const AppSheetNote('Reading details…'),
        error: (_, _) =>
            const AppSheetNote('Details aren\'t available for this photo.'),
        data: (d) => d == null
            ? const AppSheetNote('Details aren\'t available for this photo.')
            : Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.s20,
                  AppSpace.s8,
                  AppSpace.s20,
                  AppSpace.s24,
                ),
                child: _ExifTable(detail: d),
              ),
      ),
    );
  }
}

/// Flush-left key/value table: one row per field, fixed-width label column,
/// flexible value column, hairline dividers between rows.
class _ExifTable extends StatelessWidget {
  const _ExifTable({required this.detail});
  final AssetDetail detail;

  static const _labelColumnWidth = 88.0;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Taken', formatTakenDate(detail.createdAt)),
      ('Dimensions', formatDimensions(detail.width, detail.height)),
      ('Resolution', formatMegapixels(detail.width, detail.height)),
      if (formatDuration(detail.videoDuration) case final v?) ('Duration', v),
      if (formatFileSize(detail.sizeBytes) case final v?) ('Size', v),
      if (formatType(detail.mimeType) case final v?) ('Type', v),
      if (formatCoordinates(detail.latitude, detail.longitude) case final v?)
        ('Location', v),
    ];
    final colors = Theme.of(context).extension<AppColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: colors.border),
          _ExifRow(label: rows[i].$1, value: rows[i].$2),
        ],
      ],
    );
  }
}

class _ExifRow extends StatelessWidget {
  const _ExifRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          SizedBox(
            width: _ExifTable._labelColumnWidth,
            child: Text(
              label.toUpperCase(),
              style: text.exifKey.copyWith(color: colors.textMuted),
            ),
          ),
          const SizedBox(width: AppSpace.s16),
          Expanded(
            child: Text(
              value,
              style: text.exifValue.copyWith(color: scheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
