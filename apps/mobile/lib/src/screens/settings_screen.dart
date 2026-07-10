import 'package:flutter/material.dart';
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

  static const _languages = [
    _LanguageOption(code: 'zh-Hans', label: '中文'),
    _LanguageOption(code: 'en', label: 'English'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  @override
  Widget build(BuildContext context) {
    final languageLabel = _languages
        .firstWhere(
          (language) => language.code == _languageCode,
          orElse: () => _languages.first,
        )
        .label;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: const Text('更换系统语言'),
            subtitle: Text(_loadingLanguage ? '加载中...' : languageLabel),
            trailing: const Icon(Icons.chevron_right),
            onTap: _loadingLanguage ? null : _chooseLanguage,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('登出'),
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
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final language in _languages)
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
    await widget.api.setLanguageCode(selected);
    if (!mounted) return;
    setState(() => _languageCode = selected);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('登出'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('登出'),
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
