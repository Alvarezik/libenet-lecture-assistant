import 'package:flutter/foundation.dart';
import '../core/services/api_service.dart';
import '../models/lecture_model.dart';

class LectureProvider with ChangeNotifier {
  List<LectureModel> _lectures = [];
  LectureModel? _selectedLecture;
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  List<LectureModel> get lectures {
    if (_searchQuery.isEmpty) return _lectures;
    return _lectures.where((l) {
      return l.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          l.teacherName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  LectureModel? get selectedLecture => _selectedLecture;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchLectures() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _lectures = await ApiService.getLectures();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchLectureDetail(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _selectedLecture = await ApiService.getLectureDetail(id);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> createLectureAndUpload({
    required String title,
    String subject = '',
    String teacherName = '',
    required String audioFilePath,
    required int durationSeconds,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final lectureId = await ApiService.createLecture(
        title: title,
        subject: subject,
        teacherName: teacherName,
        durationSeconds: durationSeconds,
      );

      await ApiService.uploadAudioFile(lectureId, audioFilePath, durationSeconds);
      await fetchLectures();
      return lectureId;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> transcribe(int lectureId, {String language = 'ru', String engine = 'auto', String? localFilePath}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiService.transcribeLecture(lectureId, language: language, engine: engine, localFilePath: localFilePath);
      await fetchLectureDetail(lectureId);
      await fetchLectures();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> transcribeLecture(int lectureId, {String language = 'ru', String engine = 'auto', String? localFilePath}) =>
      transcribe(lectureId, language: language, engine: engine, localFilePath: localFilePath);

  Future<void> summarize(int lectureId) async {
    _isLoading = true;
    notifyListeners();
    try {
      await ApiService.summarizeLecture(lectureId);
      await fetchLectureDetail(lectureId);
      await fetchLectures();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> summarizeLecture(int lectureId) => summarize(lectureId);

  Future<void> deleteLecture(int lectureId) async {
    try {
      await ApiService.deleteLecture(lectureId);
      _lectures.removeWhere((l) => l.id == lectureId);
      if (_selectedLecture?.id == lectureId) {
        _selectedLecture = null;
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    }
  }

  void clear() {
    _lectures = [];
    _selectedLecture = null;
    _errorMessage = null;
    _searchQuery = '';
    _isLoading = false;
    notifyListeners();
  }
}
