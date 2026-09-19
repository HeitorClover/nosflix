import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../core/theme/app_theme.dart';
import '../models/rating_model.dart';
import '../models/title_model.dart';
import '../models/watch_status.dart';
import '../providers/profile_provider.dart';
import '../providers/titles_provider.dart';

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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: title.backdropUrl != null
                  ? CachedNetworkImage(imageUrl: title.backdropUrl!, fit: BoxFit.cover)
                  : Container(color: Theme.of(context).colorScheme.surfaceContainerHigh),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title.title, style: Theme.of(context).textTheme.headlineSmall),
                  if (title.originalTitle != null && title.originalTitle != title.title)
                    Text(title.originalTitle!, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      if (title.releaseYear != null) Chip(label: Text('${title.releaseYear}')),
                      Chip(label: Text(title.category.label)),
                      for (final g in title.genres.take(3)) Chip(label: Text(g)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _StatusSelector(title: title, profile: profile),
                  if (title.status == WatchStatus.assistindo && title.mediaType == 'tv')
                    _ProgressCard(
                      key: ValueKey(title.id),
                      title: title,
                    ),
                  if (title.status == WatchStatus.recomendo && title.recommendedBy != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '💡 Indicação de ${title.recommendedBy == 'heitor' ? 'Heitor' : 'Leticia'}',
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  if (title.overview != null && title.overview!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('Sinopse', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(title.overview!),
                  ],
                  const SizedBox(height: 24),
                  Text('Avaliações', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 24),
                  Text(
                    'Adicionado por ${title.addedBy == 'heitor' ? 'Heitor' : 'Leticia'} em '
                    '${DateFormat('dd/MM/yyyy').format(title.createdAt)}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          ChoiceChip(
            avatar: Icon(s.icon, size: 16),
            label: Text(s.label),
            selected: title.status == s,
            onSelected: (_) async {
              final recommendedBy = s == WatchStatus.recomendo ? profile?.name : null;
              await ref.read(titlesProvider.notifier).updateStatus(
                    title.id,
                    s.value,
                    recommendedBy: recommendedBy,
                  );
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
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            _stepper('Temporada', _season, (d) => _change(season: d)),
            _stepper('Episódio', _episode, (d) => _change(episode: d)),
          ],
        ),
      ),
    );
  }

  Widget _stepper(String label, int value, void Function(int delta) onChange) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 1 ? () => onChange(-1) : null,
        ),
        SizedBox(
          width: 32,
          child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChange(1),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, backgroundColor: color, child: Text(
                  widget.owner.displayName[0],
                  style: const TextStyle(fontSize: 11, color: Colors.white),
                )),
                const SizedBox(width: 8),
                Text(widget.owner.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (widget.editable && _saving) const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ),
            const SizedBox(height: 8),
            IgnorePointer(
              ignoring: !widget.editable,
              child: Opacity(
                opacity: widget.editable ? 1 : 0.6,
                child: RatingBar.builder(
                  initialRating: _rating,
                  minRating: 0,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemSize: 26,
                  itemBuilder: (context, _) => Icon(Icons.star_rounded, color: color),
                  onRatingUpdate: (value) {
                    setState(() => _rating = value);
                    _save();
                  },
                ),
              ),
            ),
            if (widget.editable) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _commentController,
                enabled: widget.editable,
                minLines: 1,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Comentário...',
                  isDense: true,
                ),
                onSubmitted: (_) => _save(),
                onTapOutside: (_) => _save(),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  await _pickDate();
                  await _save();
                },
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _watchedAt == null
                          ? 'Quando assistiu?'
                          : DateFormat('dd/MM/yyyy').format(_watchedAt!),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else if (_commentController.text.isNotEmpty || _watchedAt != null) ...[
              const SizedBox(height: 6),
              if (_commentController.text.isNotEmpty) Text(_commentController.text),
              if (_watchedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    DateFormat('dd/MM/yyyy').format(_watchedAt!),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
