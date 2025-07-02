import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Global App State
class AppState {
  final bool isLoading;
  final String? error;
  final bool isOnline;
  final String? currentUserId;
  final Map<String, dynamic> cache;

  const AppState({
    this.isLoading = false,
    this.error,
    this.isOnline = true,
    this.currentUserId,
    this.cache = const {},
  });

  AppState copyWith({
    bool? isLoading,
    String? error,
    bool? isOnline,
    String? currentUserId,
    Map<String, dynamic>? cache,
  }) {
    return AppState(
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isOnline: isOnline ?? this.isOnline,
      currentUserId: currentUserId ?? this.currentUserId,
      cache: cache ?? this.cache,
    );
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier() : super(const AppState());

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }

  void setError(String? error) {
    state = state.copyWith(error: error);
  }

  void setOnlineStatus(bool isOnline) {
    state = state.copyWith(isOnline: isOnline);
  }

  void setCurrentUser(String? userId) {
    state = state.copyWith(currentUserId: userId);
  }

  void updateCache(String key, dynamic value) {
    final newCache = Map<String, dynamic>.from(state.cache);
    newCache[key] = value;
    state = state.copyWith(cache: newCache);
  }

  void clearCache() {
    state = state.copyWith(cache: {});
  }
}

// Providers
final appStateProvider = StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  return AppStateNotifier();
});

// Connectivity Provider
final connectivityProvider = StreamProvider<bool>((ref) {
  return Stream.periodic(const Duration(seconds: 5), (_) => true); // Implement real connectivity check
});
