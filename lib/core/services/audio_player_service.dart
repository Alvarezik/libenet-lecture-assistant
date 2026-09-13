import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerService {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackRate = 1.0;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  bool _isSourceLoaded = false;

  PlayerState get state => _state;
  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _state == PlayerState.playing;
  double get playbackRate => _playbackRate;
  bool get isSourceLoaded => _isSourceLoaded;

  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;
  Stream<bool> get isPlayingStream => _player.onPlayerStateChanged.map((s) => s == PlayerState.playing);
  Stream<Duration> get durationStream => _player.onDurationChanged;
  Stream<Duration> get positionStream => _player.onPositionChanged;

  AudioPlayerService() {
    _stateSub = _player.onPlayerStateChanged.listen((s) => _state = s);
    _durationSub = _player.onDurationChanged.listen((d) => _duration = d);
    _positionSub = _player.onPositionChanged.listen((p) => _position = p);
  }

  Future<void> setUrl(String url) async {
    _isSourceLoaded = false;
    await _player.setSource(UrlSource(url));
    _isSourceLoaded = true;
  }

  Future<void> play() async {
    await _player.resume();
  }

  Future<void> playUrl(String url) async {
    await _player.play(UrlSource(url));
  }

  Future<void> playLocalFile(String path) async {
    _isSourceLoaded = true;
    await _player.play(DeviceFileSource(path));
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.resume();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  bool _isSeeking = false;

  Future<void> seek(Duration position) async {
    if (_isSeeking) return;
    _isSeeking = true;
    try {
      await _player.seek(position).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Ignore seek timeouts and platform race conditions
    } finally {
      _isSeeking = false;
    }
  }

  Future<void> seekRelative(int seconds) async {
    if (_isSeeking) return;
    final cur = _position.inSeconds;
    final max = _duration.inSeconds;
    final next = (cur + seconds).clamp(0, max > 0 ? max : 999999);
    await seek(Duration(seconds: next));
  }

  Future<void> setPlaybackRate(double rate) async {
    _playbackRate = rate;
    await _player.setPlaybackRate(rate);
  }

  void dispose() {
    _stateSub?.cancel();
    _durationSub?.cancel();
    _positionSub?.cancel();
    _player.stop();
    _player.dispose();
  }

  Future<void> playPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }

}
