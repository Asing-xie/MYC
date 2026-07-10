import 'package:flutter/material.dart';
import 'api_client.dart';
import 'app_strings.dart';

class AppLanguageController extends ChangeNotifier {
  AppLanguageController(this.api);

  final ApiClient api;
  String _code = 'zh-Hans';

  String get code => _code;
  bool get isEnglish => _code == 'en';
  AppStrings get strings => AppStrings(isEnglish);

  Future<void> load() async {
    final saved = await api.languageCode();
    _code = saved == 'en' ? 'en' : 'zh-Hans';
    notifyListeners();
  }

  Future<void> setCode(String code) async {
    final normalized = code == 'en' ? 'en' : 'zh-Hans';
    if (normalized == _code) return;
    _code = normalized;
    notifyListeners();
    await api.setLanguageCode(normalized);
  }

  Future<void> toggle() => setCode(isEnglish ? 'zh-Hans' : 'en');
}

class AppLanguageScope extends InheritedNotifier<AppLanguageController> {
  const AppLanguageScope({
    super.key,
    required AppLanguageController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLanguageController controllerOf(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppLanguageScope>();
    assert(scope?.notifier != null, 'AppLanguageScope is missing');
    return scope!.notifier!;
  }

  static AppStrings stringsOf(BuildContext context) => controllerOf(context).strings;
}
