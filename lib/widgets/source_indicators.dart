import 'package:flutter/material.dart';
import '../models.dart';
import '../theme.dart';

/// Small stacked SMS / Gmail icons for transaction source(s).
class SourceIndicators extends StatelessWidget {
  final List<TxSource> sources;
  final double size;

  const SourceIndicators({
    super.key,
    required this.sources,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final icons = _buildIcons();
    if (icons.isEmpty) {
      return _FallbackAvatar(size: size);
    }
    if (icons.length == 1) {
      return icons.first;
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(left: 0, top: 2, child: icons.first),
          Positioned(right: 0, bottom: 2, child: icons.last),
        ],
      ),
    );
  }

  List<Widget> _buildIcons() {
    final out = <Widget>[];
    for (final s in sources) {
      if (s == TxSource.sms) {
        out.add(_SourceIcon(
          icon: Icons.sms_outlined,
          color: AC.smsColor,
          size: size * 0.72,
        ));
      } else if (s == TxSource.gmail) {
        out.add(_SourceIcon(
          icon: Icons.mail_outline,
          color: AC.gmailColor,
          size: size * 0.72,
        ));
      }
    }
    return out;
  }
}

class _FallbackAvatar extends StatelessWidget {
  final double size;
  const _FallbackAvatar({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.touch_app_outlined, color: Colors.grey.shade600, size: size * 0.45),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _SourceIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}
