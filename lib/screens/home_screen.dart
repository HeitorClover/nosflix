import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_theme.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';
import '../providers/profile_provider.dart';
import '../providers/titles_provider.dart';
import '../widgets/nosflix_widgets.dart';
import '../widgets/title_card.dart';
import 'add_title_screen.dart';
import 'title_detail_screen.dart';

enum _HomeFilter {
  all('Tudo', Icons.apps_rounded),
  queroVer('Temos que ver juntos', Icons.bookmark_add_outlined),
  assistindo('Assistindo', Icons.play_circle_outline),
  assistidoJuntos('Já vimos juntos', Icons.favorite),
  recommendedByMe('Recomendei', Icons.campaign_outlined),
  recommendedToMe('Pra mim', Icons.card_giftcard_rounded);

  final String label;
  final IconData icon;
  const _HomeFilter(this.label, this.icon);

  bool matches(TitleModel t, Profile me) => switch (this) {
        _HomeFilter.all => true,
        _HomeFilter.queroVer => t.status == WatchStatus.queroVer,
        _HomeFilter.assistindo => t.status == WatchStatus.assistindo,
        _HomeFilter.assistidoJuntos => t.status == WatchStatus.assistidoJuntos,
        _HomeFilter.recommendedByMe => t.status == WatchStatus.recomendo && t.recommendedBy == me.name,
        _HomeFilter.recommendedToMe => t.status == WatchStatus.recomendo && t.recommendedBy != me.name,
      };
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  _HomeFilter _filter = _HomeFilter.all;
  PushStatus _pushStatus = PushStatus.unsupported;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _pushStatus = PushService.status();
    final profile = ref.read(profileProvider).profile;
    if (profile != null) PushService.syncIfGranted(profile);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _onBellTap(Profile profile) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_pushStatus == PushStatus.off) {
      try {
        final result = await PushService.enable(profile);
        if (!mounted) return;
        setState(() => _pushStatus = result);
        messenger.showSnackBar(SnackBar(
          content: Text(result == PushStatus.on
              ? 'Notificações ativadas neste aparelho!'
              : 'Não foi possível ativar as notificações.'),
        ));
      } catch (e) {
        if (!mounted) return;
        setState(() => _pushStatus = PushService.status());
        messenger.showSnackBar(SnackBar(content: Text('Erro ao ativar as notificações: $e')));
      }
    } else if (_pushStatus == PushStatus.needsInstall) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Instale o Nosflix'),
          content: const Text(
            'No iPhone, as notificações só funcionam com o app instalado:\n\n'
            '1. Toque no botão Compartilhar do Safari\n'
            '2. Escolha "Adicionar à Tela de Início"\n'
            '3. Abra o Nosflix pelo ícone novo e toque no sino',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Entendi')),
          ],
        ),
      );
    } else if (_pushStatus == PushStatus.blocked) {
      messenger.showSnackBar(const SnackBar(
        content: Text('As notificações estão bloqueadas. Libere nas configurações do navegador.'),
      ));
    } else {
      messenger.showSnackBar(const SnackBar(content: Text('Notificações já estão ativadas neste aparelho.')));
    }
  }

  void _open(TitleModel title) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TitleDetailScreen(title: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).profile ?? Profile.leticia;
    final titlesAsync = ref.watch(titlesProvider);

    return Scaffold(
      floatingActionButton: GradientFab(
        icon: Icons.add_rounded,
        label: 'Adicionar',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTitleScreen()),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                profile: profile,
                pushStatus: _pushStatus,
                onBell: () => _onBellTap(profile),
                onSwitch: () => ref.read(profileProvider.notifier).signOut(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar no catálogo...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              SizedBox(
                height: 58,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  children: [
                    for (final f in _HomeFilter.values) _pill(f),
                  ],
                ),
              ),
              Expanded(
                child: titlesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => _ErrorState(
                    message: err.toString(),
                    onRetry: () => ref.read(titlesProvider.notifier).refresh(),
                  ),
                  data: _buildContent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(_HomeFilter filter) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoicePill(
        label: filter.label,
        icon: filter.icon,
        selected: _filter == filter,
        onTap: () => setState(() => _filter = filter),
      ),
    );
  }

  Widget _buildContent(List<TitleModel> titles) {
    final me = ref.read(profileProvider).profile ?? Profile.leticia;
    var filtered = titles.where((t) => _filter.matches(t, me)).toList();
    final hasQuery = _query.trim().isNotEmpty;
    if (hasQuery) {
      final q = _query.trim().toLowerCase();
      filtered = filtered
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              (t.originalTitle?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    if (filtered.isEmpty) return const _EmptyState();

    final watching = titles.where((t) => t.status == WatchStatus.assistindo).toList();
    final showContinue = _filter == _HomeFilter.all && !hasQuery && watching.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () => ref.read(titlesProvider.notifier).refresh(),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (showContinue)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: SectionTitle('Continue assistindo'),
                  ),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: watching.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _ContinueCard(title: watching[i], onTap: () => _open(watching[i])),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: SectionTitle('Catálogo'),
                  ),
                ],
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                childAspectRatio: 2 / 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => TitleCard(title: filtered[index], onTap: () => _open(filtered[index])),
                childCount: filtered.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Profile profile;
  final PushStatus pushStatus;
  final VoidCallback onBell;
  final VoidCallback onSwitch;
  const _Header({
    required this.profile,
    required this.pushStatus,
    required this.onBell,
    required this.onSwitch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Wordmark(size: 36),
              const SizedBox(height: 4),
              Text(
                'Oi, ${profile.displayName}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
          const Spacer(),
          if (pushStatus != PushStatus.unsupported)
            IconButton(
              tooltip: switch (pushStatus) {
                PushStatus.on => 'Notificações ativadas',
                PushStatus.blocked => 'Notificações bloqueadas',
                _ => 'Ativar notificações',
              },
              icon: Icon(
                switch (pushStatus) {
                  PushStatus.on => Icons.notifications_active_rounded,
                  PushStatus.blocked => Icons.notifications_off_outlined,
                  _ => Icons.notifications_none_rounded,
                },
                color: pushStatus == PushStatus.on ? Theme.of(context).colorScheme.primary : null,
              ),
              onPressed: onBell,
            ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Trocar perfil',
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onSwitch,
                child: ProfileAvatar(profile: profile, radius: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final TitleModel title;
  final VoidCallback onTap;
  const _ContinueCard({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final image = title.backdropUrl ?? title.posterUrl;
    final progress = progressLabel(title);
    return SizedBox(
      width: 250,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (image != null)
                CachedNetworkImage(imageUrl: image, fit: BoxFit.cover)
              else
                ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHigh),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1],
                    colors: [Colors.transparent, Color(0xF2000000)],
                  ),
                ),
              ),
              Positioned(
                left: 14,
                right: 60,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      progress ?? 'Assistindo',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(gradient: context.nx.gradient, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                ),
              ),
              Positioned.fill(
                child: Material(color: Colors.transparent, child: InkWell(onTap: onTap)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.local_movies_rounded, size: 44, color: scheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'Nada por aqui ainda',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Toque em "Adicionar" pra cadastrar o primeiro título!',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text('Não deu pra carregar: $message', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
