import 'package:flutter/material.dart';

import '../auth/demo_session.dart';
import 'design.dart';

class VenueFavoriteButton extends StatelessWidget {
  const VenueFavoriteButton({
    super.key,
    required this.session,
    required this.venueId,
    this.color = AppColors.green,
  });
  final DemoSession session;
  final String venueId;
  final Color color;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      final selected = session.isFavorite(venueId);
      return IconButton(
        key: Key('favorite-$venueId'),
        tooltip: selected ? 'Bỏ yêu thích' : 'Lưu sân yêu thích',
        onPressed: () => session.toggleFavorite(venueId),
        style: IconButton.styleFrom(
          fixedSize: const Size(40, 40),
          minimumSize: const Size(40, 40),
        ),
        icon: Icon(
          selected ? Icons.favorite : Icons.favorite_border,
          color: color,
          size: 21,
        ),
      );
    },
  );
}
