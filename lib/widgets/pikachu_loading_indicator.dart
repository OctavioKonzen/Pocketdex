import 'package:flutter/material.dart';

class PikachuLoadingIndicator extends StatelessWidget {
  final double size;

  const PikachuLoadingIndicator({super.key, this.size = 80.0});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        'assets/images/pika_loader.gif', 
        width: size,
        height: size,
        gaplessPlayback: true,
      ),
    );
  }
}