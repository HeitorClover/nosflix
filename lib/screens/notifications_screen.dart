import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notification_settings.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_theme.dart';
import '../providers/profile_provider.dart';
import '../providers/titles_provider.dart';
import '../widgets/nosflix_widgets.dart';

/// Aba "Avisos": o que cada pessoa quer receber de notificação do outro.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  PushStatus _status = PushService.status();
  bool _enabling = false;

  /// Valores já alterados aqui, enquanto o banco ainda não confirmou.
  Map<String, dynamic>? _local;

  Future<void> _enableDevice(Profile me) async {
    setState(() => _enabling = true);
    try {
      final result = await PushService.enable(me);
      if (!mounted) return;
      setState(() => _status = result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = PushService.status());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao ativar as notificações: $e')));
    } finally {
      if (mounted) setState(() => _enabling = false);
    }
  }

  Future<void> _set(Profile me, Map<String, dynamic> current, String key, bool value) async {
    final next = {...current, key: value};
    setState(() => _local = next);
    await ref.read(titlesRepositoryProvider).saveNotificationPrefs(me.name, next);
  }

  Future<void> _reset(Profile me) async {
    setState(() => _local = <String, dynamic>{});
    await ref.read(titlesRepositoryProvider).saveNotificationPrefs(me.name, <String, dynamic>{});
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(profileProvider).profile ?? Profile.leticia;
    ref.listen(notificationPrefsProvider(me.name), (_, next) {
      if (next.hasValue && _local != null) setState(() => _local = null);
    });
    final saved = _local ?? ref.watch(notificationPrefsProvider(me.name)).valueOrNull ?? const <String, dynamic>{};
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: const Text('Avisos')),
      body: AppBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + kToolbarHeight + 12, 20, 40),
          children: [
            _DeviceCard(status: _status, enabling: _enabling, onEnable: () => _enableDevice(me)),
            const SizedBox(height: 24),
            Text(
              'Escolha o que você quer receber. Só vale para os avisos que chegam pra você.',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final group in notificationGroups(me)) ...[
              Row(
                children: [
                  Icon(group.icon, size: 18, color: scheme.secondary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(group.title, style: Theme.of(context).textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: GlassCard(
                  radius: 22,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    children: [
                      for (final setting in group.settings)
                        SwitchListTile(
                          value: prefEnabled(saved, setting.key),
                          onChanged: (v) => _set(me, saved, setting.key, v),
                          title: Text(setting.title, style: const TextStyle(fontSize: 15)),
                          subtitle: setting.subtitle == null
                              ? null
                              : Text(setting.subtitle!, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                          activeThumbColor: Colors.white,
                          activeTrackColor: scheme.primary,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
            Center(
              child: TextButton.icon(
                onPressed: () => _reset(me),
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Voltar ao padrão'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final PushStatus status;
  final bool enabling;
  final VoidCallback onEnable;
  const _DeviceCard({required this.status, required this.enabling, required this.onEnable});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, title, text) = switch (status) {
      PushStatus.on => (
          Icons.notifications_active_rounded,
          'Ativas neste aparelho',
          'Você recebe os avisos abaixo mesmo com o app fechado.',
        ),
      PushStatus.off => (
          Icons.notifications_none_rounded,
          'Desligadas neste aparelho',
          'Ative para receber os avisos com o app fechado.',
        ),
      PushStatus.blocked => (
          Icons.notifications_off_outlined,
          'Bloqueadas pelo navegador',
          'Libere as notificações do Nosflix nas configurações do navegador ou do celular.',
        ),
      PushStatus.needsInstall => (
          Icons.install_mobile_rounded,
          'Instale o Nosflix primeiro',
          'No iPhone: toque em Compartilhar no Safari, escolha "Adicionar à Tela de Início" e abra o Nosflix pelo ícone novo.',
        ),
      PushStatus.unsupported => (
          Icons.notifications_off_outlined,
          'Sem suporte neste aparelho',
          'Este navegador não permite notificações. Use o Nosflix instalado pelo Chrome ou pelo Safari.',
        ),
    };
    return SizedBox(
      width: double.infinity,
      child: GlassCard(
        borderColor: status == PushStatus.on ? scheme.primary : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: status == PushStatus.on ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35)),
            if (status == PushStatus.off) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: enabling ? null : onEnable,
                icon: enabling
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.notifications_active_rounded),
                label: const Text('Ativar neste aparelho'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
