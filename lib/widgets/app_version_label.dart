import 'package:flutter/material.dart';
import '../core/app_version.dart';

/// SpendLog version label (no native plugins — avoids Android Kotlin build issues).
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key, this.showName = true});

  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Text(
      appVersionLabel(showName: showName),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
            letterSpacing: 0.3,
          ),
    );
  }
}
