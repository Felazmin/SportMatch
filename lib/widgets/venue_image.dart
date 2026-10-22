import 'package:flutter/material.dart';

import '../demo/demo_finance.dart';
import '../venues/venue_catalog.dart';
import '../venues/venue_illustrations.dart';

class VenueImage extends StatelessWidget {
  const VenueImage({super.key, required this.venue, this.width, this.height});
  final VenueSummary venue;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    if (venue.image.trim().isEmpty) return _illustration();
    return venue.localPhoto
        ? Image.memory(
            decodeProof(venue.image),
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _illustration(),
          )
        : Image.asset(
            venue.image,
            width: width,
            height: height,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _illustration(),
          );
  }

  Widget _illustration() => Semantics(
    image: true,
    label: 'Ảnh minh họa sân ${venue.sport}, không phải ảnh thực tế của sân',
    child: SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 140 || constraints.maxHeight < 64;
          return Stack(
            fit: StackFit.passthrough,
            children: [
              Image.asset(
                venueIllustrationFor(venue.sport),
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: 768,
                excludeFromSemantics: true,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: Color(0xFFE8EEF0),
                  child: Center(child: Icon(Icons.sports_outlined)),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: 4,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Tooltip(
                    message: 'Ảnh minh họa, không phải ảnh thực tế của sân',
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xE61B302A),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 3,
                        ),
                        child: compact
                            ? const Icon(
                                Icons.info_outline,
                                size: 12,
                                color: Colors.white,
                              )
                            : const Text(
                                'Ảnh minh họa',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
