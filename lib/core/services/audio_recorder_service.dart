import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'notification_service.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentPath;
  
  // High-precision timing across pauses and screen lock
  DateTime? _segmentStartTime;
  int _accumulatedSeconds = 0;
  int _currentTotalSeconds = 0;

  Timer? _timer;
  final StreamController<int> _durationController = StreamController<int>.broadcast();
  final StreamController<double> _amplitudeController = StreamController<double>.broadcast();
  Timer? _amplitudeTimer;

  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  int get durationSeconds => _currentTotalSeconds;
  String? get recordedFilePath => _currentPath;
  Stream<int> get durationStream => _durationController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  String _formatTime(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    final h = (sec ~/ 3600);
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  final List<Map<String, dynamic>> _pauseEvents = [];
  DateTime? _lastPauseTime;

  List<Map<String, dynamic>> get pauseEvents => List.unmodifiable(_pauseEvents);

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.request();
    try {
      await Permission.notification.request();
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}
    return status.isGranted;
  }

  Future<bool> startRecording() async {
    try {
      if (!await hasPermission()) {
        return false;
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentPath = '${dir.path}/lecture_rec_$timestamp.m4a';

      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
        numChannels: 1,
      );

      await _recorder.start(config, path: _currentPath!);
      _isRecording = true;
      _isPaused = false;
      _accumulatedSeconds = 0;
      _segmentStartTime = DateTime.now();
      _currentTotalSeconds = 0;
      _pauseEvents.clear();
      _lastPauseTime = null;
      _durationController.add(0);

      NotificationService.showRecordingNotification(
        timeString: _formatTime(0),
        isPaused: false,
      );

      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        if (_isRecording && !_isPaused && _segmentStartTime != null) {
          final elapsedInSegment = DateTime.now().difference(_segmentStartTime!).inSeconds;
          _currentTotalSeconds = _accumulatedSeconds + elapsedInSegment;
          _durationController.add(_currentTotalSeconds);
          NotificationService.showRecordingNotification(
            timeString: _formatTime(_currentTotalSeconds),
            isPaused: false,
          );
        }
      });

      _amplitudeTimer?.cancel();
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 140), (_) async {
        if (_isRecording && !_isPaused) {
          try {
            final amp = await _recorder.getAmplitude();
            final normalized = ((amp.current + 55) / 55).clamp(0.05, 1.0);
            _amplitudeController.add(normalized);
          } catch (_) {}
        }
      });

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> pauseRecording() async {
    if (_isRecording && !_isPaused) {
      try {
        await _recorder.pause();
        if (_segmentStartTime != null) {
          _accumulatedSeconds += DateTime.now().difference(_segmentStartTime!).inSeconds;
          _segmentStartTime = null;
        }
        _isPaused = true;
        _currentTotalSeconds = _accumulatedSeconds;
        _lastPauseTime = DateTime.now();
        _durationController.add(_currentTotalSeconds);
        _amplitudeController.add(0.05);

        NotificationService.showRecordingNotification(
          timeString: _formatTime(_currentTotalSeconds),
          isPaused: true,
        );
      } catch (e) {
        debugPrint('Error pausing recording: $e');
      }
    }
  }

  Future<void> resumeRecording() async {
    if (_isRecording && _isPaused) {
      try {
        await _recorder.resume();
        if (_lastPauseTime != null) {
          final pauseDuration = DateTime.now().difference(_lastPauseTime!).inSeconds;
          if (pauseDuration >= 3) {
            _pauseEvents.add({
              'at_second': _currentTotalSeconds,
              'duration_seconds': pauseDuration,
            });
          }
          _lastPauseTime = null;
        }
        _segmentStartTime = DateTime.now();
        _isPaused = false;

        NotificationService.showRecordingNotification(
          timeString: _formatTime(_currentTotalSeconds),
          isPaused: false,
        );
      } catch (e) {
        debugPrint('Error resuming recording: $e');
      }
    }
  }

  Future<String?> stopRecording() async {
    try {
      _timer?.cancel();
      _amplitudeTimer?.cancel();
      await NotificationService.cancelRecordingNotification();

      if (_isRecording && !_isPaused && _segmentStartTime != null) {
        _accumulatedSeconds += DateTime.now().difference(_segmentStartTime!).inSeconds;
        _currentTotalSeconds = _accumulatedSeconds;
      }
      
      final path = await _recorder.stop();
      _isRecording = false;
      _isPaused = false;
      _segmentStartTime = null;

      final finalPath = path ?? _currentPath;
      if (finalPath != null) {
        final f = File(finalPath);
        if (await f.exists()) {
          final len = await f.length();
          if (len > 0) {
            return finalPath;
          }
        }
      }
      return finalPath;
    } catch (_) {
      _isRecording = false;
      await NotificationService.cancelRecordingNotification();
      return _currentPath;
    }
  }

  Future<void> cancelAndDiscard() async {
    try {
      _timer?.cancel();
      _amplitudeTimer?.cancel();
      await NotificationService.cancelRecordingNotification();

      if (_isRecording) {
        await _recorder.stop();
      }
      _isRecording = false;
      _isPaused = false;
      _segmentStartTime = null;
      _accumulatedSeconds = 0;
      _currentTotalSeconds = 0;
      _durationController.add(0);

      if (_currentPath != null) {
        final f = File(_currentPath!);
        if (await f.exists()) {
          await f.delete();
        }
        _currentPath = null;
      }
    } catch (_) {}
  }

  void dispose() {
    _timer?.cancel();
    _amplitudeTimer?.cancel();
    NotificationService.cancelRecordingNotification();
    _recorder.dispose();
    _durationController.close();
    _amplitudeController.close();
  }
}
