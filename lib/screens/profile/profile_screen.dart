import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api.dart';
import '../../core/gmail_reader.dart';
import '../../models.dart';
import '../../providers.dart';
import '../../theme.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_card.dart';
import '../../widgets/animated_list_item.dart';
import '../../widgets/app_version_label.dart';
import '../../widgets/notification_status_card.dart';
import '../../widgets/shimmer_box.dart';
import '../../widgets/sms_permission_card.dart';

enum _ProfileTab { personal, categories, cards, settings }

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  _ProfileTab _tab = _ProfileTab.personal;

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Confirm logout'),
            content: const Text('Do you really want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Logout'),
              ),
            ],
          ),
        ) ??
        false;
    if (!shouldLogout) return;
    await ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: Theme.of(context).textTheme.titleLarge),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<_ProfileTab>(
                segments: const [
                  ButtonSegment(
                    value: _ProfileTab.personal,
                    label: Text('Personal'),
                    icon: Icon(Icons.person_outline, size: 16),
                  ),
                  ButtonSegment(
                    value: _ProfileTab.categories,
                    label: Text('Categories'),
                    icon: Icon(Icons.category_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: _ProfileTab.cards,
                    label: Text('Cards'),
                    icon: Icon(Icons.credit_card_outlined, size: 16),
                  ),
                  ButtonSegment(
                    value: _ProfileTab.settings,
                    label: Text('Settings'),
                    icon: Icon(Icons.settings_outlined, size: 16),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _buildTab(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case _ProfileTab.personal:
        return _PersonalTab(key: const ValueKey('personal'), onLogout: _logout);
      case _ProfileTab.categories:
        return const _CategoriesTab(key: ValueKey('categories'));
      case _ProfileTab.cards:
        return const _CardsTab(key: ValueKey('cards'));
      case _ProfileTab.settings:
        return const _SettingsTab(key: ValueKey('settings'));
    }
  }
}

class _PersonalTab extends ConsumerWidget {
  final VoidCallback onLogout;
  const _PersonalTab({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final cs = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      children: [
        AppCard(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(Icons.person, size: 36, color: cs.primary),
              ),
              const SizedBox(height: 12),
              if (user != null) ...[
                Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(user.email, style: Theme.of(context).textTheme.bodyMedium),
              ] else
                Text('Profile', style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.04, duration: 300.ms),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          margin: EdgeInsets.zero,
          accentColor: Theme.of(context).colorScheme.error,
          onTap: onLogout,
          child: Row(
            children: [
              Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Text(
                'Sign out',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Center(child: AppVersionLabel()),
      ],
    );
  }
}

class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab({super.key});

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  bool? _gmailConnected;
  bool _savingAutoMerge = false;

  @override
  void initState() {
    super.initState();
    GmailReader.isSignedIn().then((v) {
      if (mounted) setState(() => _gmailConnected = v);
    });
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final data = await ref.read(apiProvider).get('/users/me') as Map<String, dynamic>;
      if (mounted) {
        ref.read(userProvider.notifier).state = User.fromJson(data);
      }
    } catch (_) {}
  }

  Future<void> _toggleAutoMerge(bool value) async {
    final user = ref.read(userProvider);
    if (user == null || _savingAutoMerge) return;
    setState(() => _savingAutoMerge = true);
    try {
      await ref.read(apiProvider).patch('/users/me', data: {'autoMergeSources': value});
      ref.read(userProvider.notifier).state = user.copyWith(autoMergeSources: value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update setting: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingAutoMerge = false);
    }
  }

  Future<void> _toggleGmail() async {
    if (_gmailConnected == true) {
      await GmailReader.signOut();
      setState(() => _gmailConnected = false);
    } else {
      try {
        final account = await GmailReader.signIn();
        setState(() => _gmailConnected = account != null);
        if (account != null) {
          await ref.read(todayProvider.notifier).onGmailConnected();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Gmail connected — rescanning…')),
            );
          }
        }
      } on GmailReaderException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message), duration: const Duration(seconds: 5)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final autoMerge = user?.autoMergeSources ?? true;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      children: [
        const AppCard(margin: EdgeInsets.zero, child: NotificationStatusCard()),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          margin: EdgeInsets.zero,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-merge duplicate SMS & email'),
            subtitle: const Text(
              'Combine the same payment from SMS and Gmail into one row',
              style: TextStyle(fontSize: 13),
            ),
            value: autoMerge,
            onChanged: _savingAutoMerge ? null : _toggleAutoMerge,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          margin: EdgeInsets.zero,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AC.gmailColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.mail_outline, color: AC.gmailColor, size: 20),
            ),
            title: const Text('Gmail'),
            subtitle: Text(
              !GmailReader.isConfigured
                  ? 'Setup required (GOOGLE_SETUP.md)'
                  : _gmailConnected == null
                      ? 'Checking…'
                      : _gmailConnected!
                          ? 'Connected'
                          : 'Not connected',
              style: TextStyle(
                color: _gmailConnected == true ? AC.credit : null,
                fontSize: 13,
              ),
            ),
            trailing: _gmailConnected == null
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _toggleGmail,
                    child: Text(_gmailConnected! ? 'Disconnect' : 'Connect'),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppCard(margin: EdgeInsets.zero, child: SmsPermissionCard()),
      ],
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: List.generate(
          4,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ShimmerBox(height: 56, borderRadius: AppRadius.card),
          ),
        ),
      ),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (categories) => ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () => _showCreateCategory(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New category'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...categories.asMap().entries.map((entry) {
            final cat = entry.value;
            return AnimatedListItem(
              index: entry.key,
              child: AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                accentColor: cat.color,
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(cat.icon, color: cat.color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.name, style: Theme.of(context).textTheme.titleMedium),
                          if (cat.isDefault)
                            Text('Default', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (!cat.isDefault)
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: () async {
                          try {
                            await ref
                                .read(categoriesNotifierProvider.notifier)
                                .deleteCategory(cat.id);
                          } on ApiError catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.message)),
                              );
                            }
                          }
                        },
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showCreateCategory(BuildContext context, WidgetRef ref) async {
    await AppBottomSheet.show(
      context,
      title: 'New category',
      child: _CreateCategoryForm(ref: ref),
    );
  }
}

class _CreateCategoryForm extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _CreateCategoryForm({required this.ref});

  @override
  ConsumerState<_CreateCategoryForm> createState() => _CreateCategoryFormState();
}

class _CreateCategoryFormState extends ConsumerState<_CreateCategoryForm> {
  final _nameCtrl = TextEditingController();
  String _iconKey = 'more_horiz';
  String _colorHex = '#845EF7';
  bool _saving = false;

  static const _icons = <String, IconData>{
    'restaurant': Icons.restaurant,
    'shopping_bag': Icons.shopping_bag,
    'directions_car': Icons.directions_car,
    'receipt_long': Icons.receipt_long,
    'local_gas_station': Icons.local_gas_station,
    'more_horiz': Icons.more_horiz,
  };

  static const _colors = ['#FF6B6B', '#845EF7', '#339AF0', '#20C997', '#6366F1'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(categoriesNotifierProvider.notifier).createCategory(
            name: name,
            icon: _iconKey,
            color: _colorHex,
          );
      if (mounted) Navigator.pop(context);
    } on ApiError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(hintText: 'Category name'),
          textCapitalization: TextCapitalization.words,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _icons.entries.map((e) {
            return ChoiceChip(
              selected: _iconKey == e.key,
              label: Icon(e.value, size: 18),
              onSelected: (_) => setState(() => _iconKey = e.key),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: _colors.map((hex) {
            final color = Category.fromJson({'color': hex, 'name': '', 'icon': ''}).color;
            return GestureDetector(
              onTap: () => setState(() => _colorHex = hex),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _colorHex == hex ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

class _CardsTab extends ConsumerStatefulWidget {
  const _CardsTab({super.key});

  @override
  ConsumerState<_CardsTab> createState() => _CardsTabState();
}

class _CardsTabState extends ConsumerState<_CardsTab> {
  final _nameCtrl = TextEditingController();
  final _issuerCtrl = TextEditingController();
  final _last4Ctrl = TextEditingController();
  PaymentInstrumentType _type = PaymentInstrumentType.creditCard;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _issuerCtrl.dispose();
    _last4Ctrl.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    await ref.read(paymentInstrumentsNotifierProvider.notifier).create(
          name: _nameCtrl.text.trim(),
          type: _type,
          issuer: _issuerCtrl.text.trim().isEmpty ? null : _issuerCtrl.text.trim(),
          last4: _last4Ctrl.text.length == 4 ? _last4Ctrl.text : null,
          color: '#845EF7',
          icon: 'credit_card',
        );
    _nameCtrl.clear();
    _issuerCtrl.clear();
    _last4Ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final instrumentsAsync = ref.watch(paymentInstrumentsProvider);

    return instrumentsAsync.when(
      loading: () => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ShimmerBox(height: 64, borderRadius: AppRadius.card),
          ),
        ),
      ),
      error: (e, _) => Center(child: Text('$e')),
      data: (list) => ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
        children: [
          AppCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Add instrument', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(hintText: 'Name', isDense: true),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentInstrumentType>(
                  initialValue: _type,
                  decoration: const InputDecoration(isDense: true),
                  items: PaymentInstrumentType.values
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _issuerCtrl,
                        decoration: const InputDecoration(hintText: 'Issuer', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _last4Ctrl,
                        maxLength: 4,
                        decoration: const InputDecoration(hintText: 'Last 4', isDense: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _add, child: const Text('Add')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...list.asMap().entries.map((entry) {
            final inst = entry.value;
            return AnimatedListItem(
              index: entry.key,
              child: AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                accentColor: Colors.purple,
                child: Row(
                  children: [
                    const Icon(Icons.credit_card, color: Colors.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inst.displayName, style: Theme.of(context).textTheme.titleMedium),
                          if (inst.issuer != null)
                            Text(inst.issuer!, style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => ref
                          .read(paymentInstrumentsNotifierProvider.notifier)
                          .archive(inst.id),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
