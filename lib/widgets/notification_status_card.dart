import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/notifs.dart';
import '../theme.dart';

/// Reminder diagnostics shown in Profile (permissions, alarms, pending schedules).
class NotificationStatusCard extends StatefulWidget {
  const NotificationStatusCard({super.key});

  @override
  State<NotificationStatusCard> createState() => _NotificationStatusCardState();
}

class _NotificationStatusCardState extends State<NotificationStatusCard> {
  NotificationDebugStatus? _status;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final status = await NotifManager.loadDebugStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _reschedule() async {
    setState(() => _busy = true);
    try {
      await NotifManager.rescheduleReminders();
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily reminder rescheduled')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not reschedule: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final subtitle = Theme.of(context).textTheme.bodySmall;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
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
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.notifications_outlined,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reminders',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Refresh status',
                  visualDensity: VisualDensity.compact,
                  onPressed: _loading ? null : _refresh,
                  icon: const Icon(Icons.refresh, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_error != null)
            Text(_error!, style: subtitle?.copyWith(color: cs.error))
          else if (_status != null) ...[
            _StatusRow(
              label: 'Notifications',
              ok: _status!.permissionGranted,
              detail: _status!.permissionGranted ? 'Allowed' : 'Blocked',
            ),
            if (_status!.exactAlarmsAllowed != null)
              _StatusRow(
                label: 'Exact alarms',
                ok: _status!.exactAlarmsAllowed!,
                detail: _status!.exactAlarmsAllowed! ? 'Allowed' : 'Restricted',
              ),
            _StatusRow(
              label: 'Daily reminder (00:01)',
              ok: _status!.midnightReminderScheduled,
              detail: _status!.midnightReminderScheduled
                  ? 'Scheduled'
                  : 'Not scheduled',
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 2, bottom: 6),
              child: Text(
                'Next: ${_formatWhen(_status!.nextMidnightLocal)}',
                style: subtitle,
              ),
            ),
            _StatusRow(
              label: 'Categorization nags',
              ok: _status!.activeNagCount == 0,
              detail: _status!.activeNagCount == 0
                  ? 'None active'
                  : '${_status!.activeNagCount} pending',
              neutralWhenOk: false,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Text(
                '${_status!.totalPendingCount} notification(s) queued total',
                style: subtitle,
              ),
            ),
            if (_status!.issueHint != null) ...[
              const SizedBox(height: 6),
              Text(
                _status!.issueHint!,
                style: subtitle?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: _busy ? null : _reschedule,
                  child: const Text('Reschedule'),
                ),
                if (!_status!.isHealthy)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => NotifManager.openNotificationSettings(),
                    child: const Text('Open settings'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatWhen(DateTime dt) {
    // Use epoch → local so TZ/UTC values always match device wall clock.
    final local = DateTime.fromMillisecondsSinceEpoch(
      dt.millisecondsSinceEpoch,
    );
    return DateFormat('EEE, d MMM · h:mm a').format(local);
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final bool ok;
  final String detail;
  final bool neutralWhenOk;

  const _StatusRow({
    required this.label,
    required this.ok,
    required this.detail,
    this.neutralWhenOk = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (ok && neutralWhenOk) {
      color = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    } else if (ok) {
      color = AC.credit;
    } else {
      color = Theme.of(context).colorScheme.error;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '$label · ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: detail,
                    style: TextStyle(color: color, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
