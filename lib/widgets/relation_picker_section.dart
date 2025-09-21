import 'package:flutter/material.dart';
import 'relation_picker.dart'; // where RelationPicker & RelTag live

class EditContactRelationSection extends StatelessWidget {
  final Set<RelTag> initialTags;
  final String? initialCustomLabel;
  final ValueChanged<Set<RelTag>>? onTagsChanged;
  final ValueChanged<String?>? onCustomLabelChanged;

  const EditContactRelationSection({
    super.key,
    this.initialTags = const {},
    this.initialCustomLabel,
    this.onTagsChanged,
    this.onCustomLabelChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RelationPicker(
      initialTags: initialTags,
      initialCustomLabel: initialCustomLabel,
      onTagsChanged: onTagsChanged,
      onCustomLabelChanged: onCustomLabelChanged,
    );
  }
}
