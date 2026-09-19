import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/push/push_service.dart';
import '../core/theme/app_theme.dart';
import '../models/rating_model.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';
import '../providers/profile_provider.dart';
import '../providers/titles_provider.dart';
import '../widgets/nosflix_widgets.dart';

RatingModel? _findRating(List<RatingModel> ratings, Profile owner) {
  for (final r in ratings) {
    if (r.owner == owner.name) return r;
  }
  return null;
}

class TitleDetailScreen extends ConsumerWidget {
  final TitleModel initialTitle;
  const TitleDetailScreen({super.key, required TitleModel title}) : initialTitle = title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = ref.watch(titlesProvider).valueOrNull?.firstWhere(
              (t) => t.id == initialTitle.id,
              orElse: () => initialTitle,
            ) ??
        initialTitle;
    final ratingsAsync = ref.watch(ratingsForTitleProvider(title.id));
    final profile = ref.watch(profileProvider).profile;
    final scheme = Theme.of(context).colorScheme;
    final heroImage = title.backdropUrl ?? title.posterUrl;

    return Scaffold(
      body: AppBackground(
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 320,
              pinned: true,
              backgroundColor: context.nx.base,
              leading: GlassIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Voltar',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              actions: [
                GlassIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Remover',
                  onPressed: () => _confirmDelete(context, ref),
                ),
                const SizedBox(width: 6),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: heroImage == null
                    ? Container(color: scheme.surfaceContainerHigh)
                    : ShaderMask(
                        blendMode: BlendMode.dstIn,
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: [0.45, 1],
                          colors: [Colors.black, Colors.transparent],
                        ).createShader(rect),
                        child: CachedNetworkImage(
                          imageUrl: heroImage,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                      ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title.title, style: Theme.of(context).textTheme.headlineMedium),
                        if (title.originalTitle != null && title.originalTitle != title.title)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              title.originalTitle!,
                              style: TextStyle(color: scheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (title.releaseYear != null) _MetaPill('${title.releaseYear}'),
                            _MetaPill(title.category.label, icon: title.category.icon, highlight: true),
                            for (final g in title.genres.take(3)) _MetaPill(g),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _StatusSelector(title: title, profile: profile),
                        if (title.status == WatchStatus.assistindo && title.mediaType == 'tv')
                          _ProgressCard(key: ValueKey(title.id), title: title),
                        if (title.status == WatchStatus.recomendo && title.recommendedBy != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              children: [
                                Icon(Icons.campaign_rounded, size: 18, color: scheme.secondary),
                                const SizedBox(width: 8),
                                Text(
                                  'Indicação de ${title.recommendedBy == 'heitor' ? 'Heitor' : 'Leticia'}',
                                  style: TextStyle(color: scheme.secondary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        if (title.overview != null && title.overview!.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const SectionTitle('Sinopse'),
                          const SizedBox(height: 10),
                          Text(
                            title.overview!,
                            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.85), height: 1.5, fontSize: 15),
                          ),
                        ],
                        const SizedBox(height: 28),
                        const SectionTitle('Avaliações'),
                        const SizedBox(height: 12),
                        ratingsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Text('Erro ao carregar avaliações: $e'),
                          data: (ratings) => Column(
                            children: [
                              for (final p in Profile.values)
                                _RatingCard(
                                  titleId: title.id,
                                  owner: p,
                                  existing: _findRating(ratings, p),
                                  editable: profile == p,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'Adicionado por ${title.addedBy == 'heitor' ? 'Heitor' : 'Leticia'} em '
                            '${DateFormat('dd/MM/yyyy').format(title.createdAt)}',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover título?'),
        content: Text('Isso vai apagar "${initialTitle.title}" e as avaliações de vocês dois.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remover')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(titlesProvider.notifier).deleteTitle(initialTitle.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _MetaPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final bool highlight;
  const _MetaPill(this.text, {this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = highlight ? scheme.secondary : scheme.onSurface.withValues(alpha: 0.8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? scheme.primary.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _StatusSelector extends ConsumerWidget {
  final TitleModel title;
  final Profile? profile;
  const _StatusSelector({required this.title, required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in WatchStatus.values)
          ChoicePill(
            icon: s.icon,
            label: s.label,
            selected: title.status == s,
            onTap: () async {
              final recommendedBy = s == WatchStatus.recomendo ? profile?.name : null;
              final newRecommendation = s == WatchStatus.recomendo && title.status != s;
              await ref.read(titlesProvider.notifier).updateStatus(
                    title.id,
                    s.value,
                    recommendedBy: recommendedBy,
                  );
              if (newRecommendation && profile != null) {
                // Sem await: o aviso segue em segundo plano.
                PushService.notifyRecommendation(titleId: title.id, from: profile!);
              }
            },
          ),
      ],
    );
  }
}

class _ProgressCard extends ConsumerStatefulWidget {
  final TitleModel title;
  const _ProgressCard({super.key, required this.title});

  @override
  ConsumerState<_ProgressCard> createState() => _ProgressCardState();
}

class _ProgressCardState extends ConsumerState<_ProgressCard> {
  late int _season;
  late int _episode;

  @override
  void initState() {
    super.initState();
    _season = widget.title.currentSeason ?? 1;
    _episode = widget.title.currentEpisode ?? 1;
  }

  void _change({int season = 0, int episode = 0}) {
    setState(() {
      _season = (_season + season).clamp(1, 999);
      _episode = (_episode + episode).clamp(1, 9999);
    });
    ref.read(titlesProvider.notifier).updateProgress(
          widget.title.id,
          season: _season,
          episode: _episode,
        );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary.withValues(alpha: 0.22), scheme.primary.withValues(alpha: 0.05)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 18, color: scheme.secondary),
              const SizedBox(width: 8),
              Text('Onde paramos', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.secondary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _stepper('Temporada', _season, (d) => _change(season: d))),
              Container(width: 1, height: 64, color: Colors.white12),
              Expanded(child: _stepper('Episódio', _episode, (d) => _change(episode: d))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepper(String label, int value, void Function(int delta) onChange) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              onPressed: value > 1 ? () => onChange(-1) : null,
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle_rounded, color: scheme.primary),
              onPressed: () => onChange(1),
            ),
          ],
        ),
      ],
    );
  }
}

class _RatingCard extends ConsumerStatefulWidget {
  final String titleId;
  final Profile owner;
  final RatingModel? existing;
  final bool editable;

  const _RatingCard({
    required this.titleId,
    required this.owner,
    required this.existing,
    required this.editable,
  });

  @override
  ConsumerState<_RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends ConsumerState<_RatingCard> {
  late double _rating;
  late TextEditingController _commentController;
  DateTime? _watchedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rating = widget.existing?.rating ?? 0;
    _commentController = TextEditingController(text: widget.existing?.comment ?? '');
    _watchedAt = widget.existing?.watchedAt;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repo = ref.read(titlesRepositoryProvider);
    await repo.upsertRating(RatingModel(
      id: widget.existing?.id ?? '',
      titleId: widget.titleId,
      owner: widget.owner.name,
      rating: _rating == 0 ? null : _rating,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      watchedAt: _watchedAt,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    ref.invalidate(ratingsForTitleProvider(widget.titleId));
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _watchedAt ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _watchedAt = picked);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.owner.seedColor;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: widget.editable ? 0.45 : 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(profile: widget.owner, radius: 14),
              const SizedBox(width: 10),
              Text(widget.owner.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              if (widget.editable) ...[
                const SizedBox(width: 8),
                Text('você', style: TextStyle(color: muted, fontSize: 12)),
              ],
              const Spacer(),
              if (widget.editable && _saving)
                const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 10),
          IgnorePointer(
            ignoring: !widget.editable,
            child: Opacity(
              opacity: widget.editable ? 1 : 0.7,
              child: RatingBar.builder(
                initialRating: _rating,
                minRating: 0,
                allowHalfRating: true,
                itemCount: 5,
                itemSize: 30,
                unratedColor: Colors.white24,
                itemBuilder: (context, _) => Icon(Icons.star_rounded, color: color),
                onRatingUpdate: (value) {
                  setState(() => _rating = value);
                  _save();
                },
              ),
            ),
          ),
          if (widget.editable) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Escreva um comentário...', isDense: true),
              onSubmitted: (_) => _save(),
              onTapOutside: (_) => _save(),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                await _pickDate();
                await _save();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(
                      _watchedAt == null ? 'Quando assistiu?' : DateFormat('dd/MM/yyyy').format(_watchedAt!),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_commentController.text.isNotEmpty || _watchedAt != null) ...[
            const SizedBox(height: 8),
            if (_commentController.text.isNotEmpty) Text(_commentController.text),
            if (_watchedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  DateFormat('dd/MM/yyyy').format(_watchedAt!),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
