import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/tmdb_service.dart';
import '../models/watch_status.dart';
import '../providers/profile_provider.dart';
import '../providers/titles_provider.dart';

class AddTitleScreen extends ConsumerStatefulWidget {
  const AddTitleScreen({super.key});

  @override
  ConsumerState<AddTitleScreen> createState() => _AddTitleScreenState();
}

class _AddTitleScreenState extends ConsumerState<AddTitleScreen> {
  final _tmdb = TmdbService();
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<TmdbSearchResult> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _search(value));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await _tmdb.search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addFromTmdb(TmdbSearchResult r) async {
    final category = await _pickCategory(r.mediaType);
    if (category == null) return;

    final profile = ref.read(profileProvider).profile;
    if (profile == null) return;

    await ref.read(titlesProvider.notifier).addTitle({
      'tmdb_id': r.id,
      'media_type': r.mediaType,
      'category': category.value,
      'title': r.title,
      'original_title': r.originalTitle,
      'poster_path': r.posterPath,
      'backdrop_path': r.backdropPath,
      'overview': r.overview,
      'release_year': r.releaseYear,
      'genres': r.genres,
      'status': WatchStatus.queroVer.value,
      'recommended_by': null,
      'added_by': profile.name,
    });

    if (mounted) Navigator.of(context).pop();
  }

  Future<TitleCategory?> _pickCategory(String mediaType) async {
    final suggestion = mediaType == 'movie' ? TitleCategory.filme : TitleCategory.serie;
    return showModalBottomSheet<TitleCategory>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Isso é...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            for (final c in TitleCategory.values)
              ListTile(
                title: Text(c.label),
                trailing: c == suggestion ? const Icon(Icons.star, size: 18) : null,
                onTap: () => Navigator.of(context).pop(c),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final configured = _tmdb.isConfigured;

    return Scaffold(
      appBar: AppBar(title: const Text('Adicionar título')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Nome do filme, série ou desenho...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onChanged,
            ),
          ),
          if (!configured)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: Colors.amber.withValues(alpha: 0.15),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'TMDB_API_KEY não configurada no .env — a busca automática não vai funcionar até você '
                    'colocar sua chave da TMDB (themoviedb.org/settings/api).',
                  ),
                ),
              ),
            ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erro: $_error', style: const TextStyle(color: Colors.redAccent)),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final r = _results[index];
                return ListTile(
                  leading: SizedBox(
                    width: 44,
                    child: r.posterPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              'https://image.tmdb.org/t/p/w92${r.posterPath}',
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Icon(Icons.movie_outlined),
                  ),
                  title: Text(r.title),
                  subtitle: Text([
                    if (r.releaseYear != null) r.releaseYear.toString(),
                    r.mediaType == 'movie' ? 'Filme' : 'Série',
                  ].join(' • ')),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => _addFromTmdb(r),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
