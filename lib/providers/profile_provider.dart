import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

const _prefsKey = 'nosflix_profile';

class ProfileState {
  final Profile? profile;
  final bool loading;
  const ProfileState({this.profile, this.loading = true});
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(const ProfileState()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final profile = saved == 'heitor'
        ? Profile.heitor
        : saved == 'leticia'
            ? Profile.leticia
            : null;
    state = ProfileState(profile: profile, loading: false);
  }

  Future<void> select(Profile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, profile.name);
    state = ProfileState(profile: profile, loading: false);
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    state = const ProfileState(profile: null, loading: false);
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});
