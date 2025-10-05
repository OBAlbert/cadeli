import 'package:shared_preferences/shared_preferences.dart';

class HiddenChatsStore {
  static const _k = 'hidden_chat_ids';

  static Future<Set<String>> get() async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(_k) ?? const []).toSet();
  }

  static Future<void> add(String id) async {
    final p = await SharedPreferences.getInstance();
    final s = (p.getStringList(_k) ?? const []).toSet()..add(id);
    await p.setStringList(_k, s.toList());
  }

  static Future<void> remove(String id) async {
    final p = await SharedPreferences.getInstance();
    final s = (p.getStringList(_k) ?? const []).toSet()..remove(id);
    await p.setStringList(_k, s.toList());
  }

  static Future<void> clearAll() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k);
  }
}
