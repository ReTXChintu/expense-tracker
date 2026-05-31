import 'package:flutter/material.dart';

/// Full logo on splash — fixed height, width from aspect ratio.
const double kSplashLogoHeight = 96;

const Color kSplashBackground = Color(0xFFF5F6FA);

class BrandedSplashOverlay extends StatelessWidget {
  const BrandedSplashOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: kSplashBackground,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Image.asset(
            'assets/branding/logo_full.png',
            height: kSplashLogoHeight,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            gaplessPlayback: true,
          ),
        ),
      ),
    );
  }
}
