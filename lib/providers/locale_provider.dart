import 'package:flutter/material.dart';
import '../core/localization/app_locale.dart';
import '../core/services/storage_service.dart';

class LocaleProvider extends ChangeNotifier {
  String _languageCode = 'ru';
  AppLocale _locale = const AppLocale('ru');

  LocaleProvider() {
    _loadSavedLocale();
  }

  String get languageCode => _languageCode;
  AppLocale get t => _locale;
  Locale get flutterLocale => Locale(_languageCode);
  bool get isRu => _languageCode == 'ru';
  bool get isEn => _languageCode == 'en';

  Future<void> _loadSavedLocale() async {
    final saved = await StorageService.getLanguage();
    if (saved == 'en' || saved == 'ru') {
      _languageCode = saved;
      _locale = AppLocale(saved);
      notifyListeners();
    }
  }

  Future<void> setLocale(String langCode) async {
    if (langCode != 'ru' && langCode != 'en') return;
    if (_languageCode == langCode) return;

    _languageCode = langCode;
    _locale = AppLocale(langCode);
    await StorageService.setLanguage(langCode);
    notifyListeners();
  }
}
