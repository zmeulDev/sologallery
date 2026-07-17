import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../services/photo_library_service.dart' show AssetDetail;
import '../detail_providers.dart';
import '../domain/asset_detail_display.dart';

/// Opens the EXIF/metadata sheet for [assetId] from the detail viewer.
Future<void> showExifSheet(BuildContext context, String assetId) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => ExifSheet(assetId: assetId),
  );
}

/// Bottom sheet of `photo_manager`-native metadata as design-system EXIF chips
/// (uppercase key over a heavier value). Reads [assetDetailProvider]; renders
/// explicit loading / error / data states.
class ExifSheet extends ConsumerWidget {
  const ExifSheet({super.key, required this.assetId});

  final String assetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final detail = ref.watch(assetDetailProvider(assetId));

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _Title(colors: colors),
              const SizedBox(height: 18),
              detail.when(
                loading: () => const _SheetNote('Reading details…'),
                error: (_, _) =>
                    const _SheetNote('Details aren\'t available for this photo.'),
                data: (d) => d == null
                    ? const _SheetNote(
                        'Details aren\'t available for this photo.')
                    : _Chips(detail: d),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return Text(
      'DETAILS',
      style: text.sectionLabel.copyWith(color: colors.textSecondary),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.detail});
  final AssetDetail detail;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      _ExifChip(label: 'Taken', value: formatTakenDate(detail.createdAt)),
      _ExifChip(
        label: 'Dimensions',
        value: formatDimensions(detail.width, detail.height),
      ),
      _ExifChip(
        label: 'Resolution',
        value: formatMegapixels(detail.width, detail.height),
      ),
      if (formatFileSize(detail.sizeBytes) case final size?)
        _ExifChip(label: 'Size', value: size),
      if (formatType(detail.mimeType) case final type?)
        _ExifChip(label: 'Type', value: type),
      if (formatCoordinates(detail.latitude, detail.longitude) case final gps?)
        _ExifChip(label: 'Location', value: gps),
    ];
    return Wrap(spacing: 28, runSpacing: 18, children: chips);
  }
}

class _ExifChip extends StatelessWidget {
  const _ExifChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).extension<AppTextStyles>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: text.exifKey.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: text.exifValue.copyWith(color: scheme.onSurface),
        ),
      ],
    );
  }
}

class _SheetNote extends StatelessWidget {
  const _SheetNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final styles = Theme.of(context).extension<AppTextStyles>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: styles.body.copyWith(color: colors.textSecondary),
      ),
    );
  }
}
