import 'package:flutter/material.dart';

class PhotoCard extends StatelessWidget {
  const PhotoCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: child,
      ),
    );
  }
}
