import 'package:flutter/material.dart';

/// Fullscreen image viewer with pinch-to-zoom and pan via [InteractiveViewer].
/// Tap the image (or the close button) to dismiss.
class ImageViewerPage extends StatelessWidget {
  final String imageUrl;
  final String? heroTag;

  const ImageViewerPage({
    super.key,
    required this.imageUrl,
    this.heroTag,
  });

  static Future<void> open(
    BuildContext context, {
    required String imageUrl,
    String? heroTag,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: ImageViewerPage(imageUrl: imageUrl, heroTag: heroTag),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      imageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        );
      },
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                minScale: 1.0,
                maxScale: 5.0,
                child: Center(
                  child: heroTag != null
                      ? Hero(tag: heroTag!, child: image)
                      : image,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: Material(
              color: Colors.black.withValues(alpha: 0.5),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Đóng',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
