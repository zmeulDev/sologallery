import 'package:flutter/material.dart';

import '../../../widgets/filter_pill.dart';
import '../../../widgets/section_header.dart';

/// A wrap of label chips that each run a content search for their text — the
/// tap-to-browse entry into ML labels. [labels] arrives ranked by how many
/// photos carry it (see `topBrowseLabelsProvider`), so the widest doors are
/// first; it is never empty, the caller drops the section instead.
class BrowseLabels extends StatelessWidget {
  const BrowseLabels({super.key, required this.labels, required this.onTap});

  final List<String> labels;
  final void Function(String) onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(label: 'On-device labels'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in labels)
                FilterPill(
                  label: label,
                  selected: false,
                  onTap: () => onTap(label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
