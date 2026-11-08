import 'dart:async';
import 'package:archbtw_sh/widgets/in_game_music_hud.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SiteMusicController extends ChangeNotifier {
  SiteMusicController._();
  static final SiteMusicController instance = SiteMusicController._();

  AudioPlayer? _audioPlayer;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;

  String? _albumTitle;
  String? _audioPath;
  List<String> _tracks = const [];
  int _currentTrackIndex = 0;
  bool _isPlaying = false;
  bool _hasActiveSession = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  final List<String> _visibleAlbumPaths = [];
  int _activeGameCount = 0;

  String? get albumTitle => _albumTitle;
  String? get audioPath => _audioPath;
  List<String> get tracks => _tracks;
  int get currentTrackIndex => _currentTrackIndex;
  bool get isPlaying => _isPlaying;
  bool get hasActiveSession => _hasActiveSession && _tracks.isNotEmpty;
  Duration get duration => _duration;
  Duration get position => _position;

  String get currentTrackName {
    if (_tracks.isEmpty) return '';
    final idx = _currentTrackIndex.clamp(0, _tracks.length - 1);
    return _tracks[idx];
  }

  bool isAlbumLoaded(String audioPath) =>
      _hasActiveSession && _audioPath == audioPath;

  /// Show the floating toast when a track session is active, the user is not
  /// inside a full-screen game, and the user is not currently viewing the
  /// AlbumDetailPage for the active album.
  bool get shouldShowFloatingToast {
    if (!hasActiveSession || _activeGameCount > 0) return false;
    final currentVisible = _visibleAlbumPaths.isNotEmpty
        ? _visibleAlbumPaths.last
        : null;
    return currentVisible != _audioPath;
  }

  void registerVisibleAlbum(String audioPath) {
    _visibleAlbumPaths.add(audioPath);
    WidgetsBindingFlush.scheduleNotify(notifyListeners);
  }

  void unregisterVisibleAlbum(String audioPath) {
    _visibleAlbumPaths.remove(audioPath);
    WidgetsBindingFlush.scheduleNotify(notifyListeners);
  }

  void enterGame() {
    _activeGameCount++;
    if (_isPlaying) {
      pause();
    } else {
      WidgetsBindingFlush.scheduleNotify(notifyListeners);
    }
  }

  void exitGame() {
    if (_activeGameCount > 0) {
      _activeGameCount--;
    }
    WidgetsBindingFlush.scheduleNotify(notifyListeners);
  }

  AudioPlayer _ensurePlayer() {
    if (_audioPlayer != null) return _audioPlayer!;
    configureBackgroundAudioContext();
    final player = AudioPlayer();
    _audioPlayer = player;

    _durationSubscription = player.onDurationChanged.listen((d) {
      _duration = d;
      notifyListeners();
    });

    _positionSubscription = player.onPositionChanged.listen((p) {
      _position = p;
      notifyListeners();
    });

    _playerCompleteSubscription = player.onPlayerComplete.listen((_) {
      next();
    });

    _playerStateSubscription = player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    return player;
  }

  Future<void> playAlbumTrack({
    required String albumTitle,
    required String audioPath,
    required List<String> tracks,
    required int trackIndex,
  }) async {
    if (tracks.isEmpty) return;
    final bool sameAlbum = _audioPath == audioPath;
    _albumTitle = albumTitle;
    _audioPath = audioPath;
    _tracks = List<String>.unmodifiable(tracks);
    _currentTrackIndex =
        (trackIndex % _tracks.length + _tracks.length) % _tracks.length;
    _hasActiveSession = true;
    _isPlaying = true;
    if (!sameAlbum) {
      _position = Duration.zero;
      _duration = Duration.zero;
    }
    notifyListeners();

    try {
      final player = _ensurePlayer();
      final track = _tracks[_currentTrackIndex];
      await player.play(AssetSource('$_audioPath$track'));
    } catch (e) {
      debugPrint('SiteMusicController play error: $e');
    }
  }

  Future<void> togglePlayPause({
    String? albumTitle,
    String? audioPath,
    List<String>? tracks,
    int? selectedIndex,
  }) async {
    // If toggling from an album that isn't currently loaded, load and play it
    if (audioPath != null &&
        tracks != null &&
        tracks.isNotEmpty &&
        (!_hasActiveSession || _audioPath != audioPath)) {
      await playAlbumTrack(
        albumTitle: albumTitle ?? '',
        audioPath: audioPath,
        tracks: tracks,
        trackIndex: selectedIndex ?? 0,
      );
      return;
    }

    if (!_hasActiveSession || _tracks.isEmpty) return;

    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

  Future<void> pause() async {
    _isPlaying = false;
    notifyListeners();
    try {
      await _audioPlayer?.pause();
    } catch (e) {
      debugPrint('SiteMusicController pause error: $e');
    }
  }

  Future<void> resume() async {
    if (_tracks.isEmpty || _audioPath == null) return;
    _isPlaying = true;
    _hasActiveSession = true;
    notifyListeners();
    try {
      final player = _ensurePlayer();
      if (_position == Duration.zero) {
        final track = _tracks[_currentTrackIndex];
        await player.play(AssetSource('$_audioPath$track'));
      } else {
        await player.resume();
      }
    } catch (e) {
      debugPrint('SiteMusicController resume error: $e');
    }
  }

  Future<void> next({
    String? albumTitle,
    String? audioPath,
    List<String>? tracks,
  }) async {
    if (audioPath != null &&
        tracks != null &&
        tracks.isNotEmpty &&
        (!_hasActiveSession || _audioPath != audioPath)) {
      await playAlbumTrack(
        albumTitle: albumTitle ?? '',
        audioPath: audioPath,
        tracks: tracks,
        trackIndex: 1 % tracks.length,
      );
      return;
    }
    if (_tracks.isEmpty || _audioPath == null) return;
    final nextIdx = (_currentTrackIndex + 1) % _tracks.length;
    await playAlbumTrack(
      albumTitle: _albumTitle ?? '',
      audioPath: _audioPath!,
      tracks: _tracks,
      trackIndex: nextIdx,
    );
  }

  Future<void> previous({
    String? albumTitle,
    String? audioPath,
    List<String>? tracks,
  }) async {
    if (audioPath != null &&
        tracks != null &&
        tracks.isNotEmpty &&
        (!_hasActiveSession || _audioPath != audioPath)) {
      await playAlbumTrack(
        albumTitle: albumTitle ?? '',
        audioPath: audioPath,
        tracks: tracks,
        trackIndex: (tracks.length - 1) % tracks.length,
      );
      return;
    }
    if (_tracks.isEmpty || _audioPath == null) return;
    final prevIdx = (_currentTrackIndex - 1 + _tracks.length) % _tracks.length;
    await playAlbumTrack(
      albumTitle: _albumTitle ?? '',
      audioPath: _audioPath!,
      tracks: _tracks,
      trackIndex: prevIdx,
    );
  }

  Future<void> seek(Duration target) async {
    _position = target;
    notifyListeners();
    try {
      await _audioPlayer?.seek(target);
    } catch (e) {
      debugPrint('SiteMusicController seek error: $e');
    }
  }

  Future<void> stopAndDismiss() async {
    _isPlaying = false;
    _hasActiveSession = false;
    _position = Duration.zero;
    notifyListeners();
    try {
      await _audioPlayer?.stop();
    } catch (e) {
      debugPrint('SiteMusicController stop error: $e');
    }
  }

  @visibleForTesting
  void resetForTest() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _albumTitle = null;
    _audioPath = null;
    _tracks = const [];
    _currentTrackIndex = 0;
    _isPlaying = false;
    _hasActiveSession = false;
    _duration = Duration.zero;
    _position = Duration.zero;
    _visibleAlbumPaths.clear();
    _activeGameCount = 0;
  }
}

class WidgetsBindingFlush {
  static void scheduleNotify(VoidCallback callback) {
    Future.microtask(callback);
  }
}

