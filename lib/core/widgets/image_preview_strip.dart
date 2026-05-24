import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../constants/app_colors.dart';

class ImagePreviewStrip extends StatelessWidget {
  final List<XFile> images;
  final ValueChanged<int> onRemove;

  const ImagePreviewStrip({
    super.key,
    required this.images,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.channelSidebar,
      height: 96,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        itemCount: images.length,
        itemBuilder: (_, i) => _PreviewItem(
          file: images[i],
          onRemove: () => onRemove(i),
        ),
      ),
    );
  }
}

class _PreviewItem extends StatefulWidget {
  final XFile file;
  final VoidCallback onRemove;

  const _PreviewItem({required this.file, required this.onRemove});

  @override
  State<_PreviewItem> createState() => _PreviewItemState();
}

class _PreviewItemState extends State<_PreviewItem> {
  late final Future<Uint8List> _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = widget.file.readAsBytes();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          width: 76,
          height: 76,
          child: FutureBuilder<Uint8List>(
            future: _bytes,
            builder: (_, snap) => snap.hasData
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(snap.data!, fit: BoxFit.cover),
                  )
                : Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2),
                    ),
                  ),
          ),
        ),
        Positioned(
          top: 2,
          right: 10,
          child: GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 12),
            ),
          ),
        ),
      ],
    );
  }
}
