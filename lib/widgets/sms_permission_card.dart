import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';

/// SMS read permission status for Today auto-import.
class SmsPermissionCard extends StatefulWidget {
  const SmsPermissionCard({super.key});

  @override
  State<SmsPermissionCard> createState() => _SmsPermissionCardState();
}

class _SmsPermissionCardState extends State<SmsPermissionCard> {
  PermissionStatus? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final status = await Permission.sms.status;
    if (mounted) {
      setState(() {
        _status = status;
        _loading = false;
      });
    }
  }

  Future<void> _request() async {
    final result = await Permission.sms.request();
    if (mounted) setState(() => _status = result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final granted = _status?.isGranted ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AC.smsColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.sms_outlined, color: AC.smsColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('SMS access', style: Theme.of(context).textTheme.titleSmall),
              ),
              if (_loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Refresh',
                  visualDensity: VisualDensity.compact,
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Allow SMS access to automatically import bank transaction alerts on the Today screen.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!_loading && _status != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  granted ? Icons.check_circle_outline : Icons.error_outline,
                  size: 18,
                  color: granted ? AC.credit : cs.error,
                ),
                const SizedBox(width: 8),
                Text(
                  granted ? 'Allowed' : 'Not allowed',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: granted ? AC.credit : cs.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (!granted)
                  FilledButton.tonal(onPressed: _request, child: const Text('Grant access')),
                TextButton(
                  onPressed: openAppSettings,
                  child: const Text('Open settings'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
