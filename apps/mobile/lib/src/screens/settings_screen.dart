import 'package:flutter/material.dart';
import '../services/app_language.dart';
import '../services/api_client.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.api,
    required this.onLogout,
  });

  final ApiClient api;
  final Future<void> Function() onLogout;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _languageCode = 'zh-Hans';
  bool _loadingLanguage = true;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLanguageScope.stringsOf(context);
    final languages = [
      _LanguageOption(code: 'zh-Hans', label: strings.chinese),
      _LanguageOption(code: 'en', label: strings.english),
    ];
    final languageLabel = languages
        .firstWhere(
          (language) => language.code == _languageCode,
          orElse: () => languages.first,
        )
        .label;

    return Scaffold(
      appBar: AppBar(title: Text(strings.settings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(strings.changeLanguage),
            subtitle: Text(_loadingLanguage ? strings.loading : languageLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: _loadingLanguage ? null : _chooseLanguage,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(strings.logout),
            trailing: _loggingOut
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _loggingOut ? null : _confirmLogout,
          ),
        ],
      ),
    );
  }

  Future<void> _loadLanguage() async {
    final code = await widget.api.languageCode();
    if (!mounted) return;
    setState(() {
      _languageCode = code == 'en' ? 'en' : 'zh-Hans';
      _loadingLanguage = false;
    });
  }

  Future<void> _chooseLanguage() async {
    final strings = AppLanguageScope.stringsOf(context);
    final languageController = AppLanguageScope.controllerOf(context);
    final languages = [
      _LanguageOption(code: 'zh-Hans', label: strings.chinese),
      _LanguageOption(code: 'en', label: strings.english),
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in languages)
              ListTile(
                title: Text(language.label),
                trailing: language.code == _languageCode ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(language.code),
              ),
          ],
        ),
      ),
    );
    if (selected == null || selected == _languageCode) return;
    await languageController.setCode(selected);
    if (!mounted) return;
    setState(() => _languageCode = selected);
  }

  Future<void> _confirmLogout() async {
    final strings = AppLanguageScope.stringsOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.logout),
        content: Text(strings.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.logout),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loggingOut = true);
    await widget.onLogout();
  }
}

class _LanguageOption {
  const _LanguageOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}
