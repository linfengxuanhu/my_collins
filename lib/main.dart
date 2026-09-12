import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

// ============================================================
// 常量
// ============================================================
const kStatusLabels = ['待抄', '已抄', '已描', '已掌握'];

// ============================================================
// 数据模型
// ============================================================
class Entry {
  final String word, definition;
  const Entry(this.word, this.definition);
  factory Entry.fromJson(Map<String, dynamic> j) =>
      Entry(j['word'] ?? '', j['definition'] ?? '');
}

@immutable
class Word {
  final String word, source, definition, example, note;
  final int status;

  const Word({
    required this.word,
    this.source = '',
    this.definition = '',
    this.example = '',
    this.note = '',
    this.status = 0,
  });

  Word copyWith({
    String? word,
    String? source,
    String? definition,
    String? example,
    String? note,
    int? status,
  }) =>
      Word(
        word: word ?? this.word,
        source: source ?? this.source,
        definition: definition ?? this.definition,
        example: example ?? this.example,
        note: note ?? this.note,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'source': source,
        'definition': definition,
        'example': example,
        'note': note,
        'status': status,
      };

  factory Word.fromJson(Map<String, dynamic> j) => Word(
        word: (j['word'] ?? '').toString(),
        source: (j['source'] ?? '').toString(),
        definition: (j['definition'] ?? '').toString(),
        example: (j['example'] ?? '').toString(),
        note: (j['note'] ?? '').toString(),
        status: j['status'] is int ? j['status'] as int : 0,
      );
}

// ============================================================
// 根 App
// ============================================================
class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  List<Word> words = [];
  List<Entry> dict = [];
  Map<String, Entry> dictIndex = {};
  bool loading = true;

  Future<void> _saveQueue = Future.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('words');
    if (s != null) {
      try {
        words = (jsonDecode(s) as List)
            .map((x) => Word.fromJson(x as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('解析我的词库失败: $e');
      }
    }
    try {
      final b = await rootBundle.load('assets/dictionary.json.gz');
      final raw = GZipCodec().decode(b.buffer.asUint8List());
      final list = (jsonDecode(utf8.decode(raw)) as List)
          .map((x) => Entry.fromJson(x))
          .toList();
      dict = list;
      dictIndex = {for (final e in list) e.word.toLowerCase(): e};
    } catch (e) {
      debugPrint('加载本地词典失败: $e');
    }
    if (mounted) setState(() => loading = false);
  }

  void _save() {
    _saveQueue = _saveQueue.then((_) async {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        'words',
        jsonEncode(words.map((x) => x.toJson()).toList()),
      );
    });
  }

  void _add(Word w) {
    final i = words.indexWhere(
      (x) => x.word.toLowerCase() == w.word.toLowerCase(),
    );
    setState(() {
      if (i < 0) {
        words.add(w);
      } else {
        final old = words[i];
        words[i] = old.copyWith(
          source: w.source.isNotEmpty ? w.source : old.source,
          definition: w.definition.isNotEmpty ? w.definition : old.definition,
          example: w.example.isNotEmpty ? w.example : old.example,
        );
      }
    });
    _save();
  }

  void _setStatus(Word w, int s) {
    final i = words.indexWhere(
      (x) => x.word.toLowerCase() == w.word.toLowerCase(),
    );
    if (i < 0) return;
    setState(() => words[i] = words[i].copyWith(status: s));
    _save();
  }

  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '我的柯林斯',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
        home: Home(
          words: words,
          dict: dict,
          dictIndex: dictIndex,
          loading: loading,
          add: _add,
          setStatus: _setStatus,
        ),
      );
}

// ============================================================
// Home
// ============================================================
class Home extends StatefulWidget {
  final List<Word> words;
  final List<Entry> dict;
  final Map<String, Entry> dictIndex;
  final bool loading;
  final void Function(Word) add;
  final void Function(Word, int) setStatus;

  const Home({
    super.key,
    required this.words,
    required this.dict,
    required this.dictIndex,
    required this.loading,
    required this.add,
    required this.setStatus,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  final q = TextEditingController();

  @override
  void dispose() {
    q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        appBar: AppBar(title: const Text('我的柯林斯')),
        body: tab == 0
            ? _home(c)
            : tab == 1
                ? _library(c)
                : _tree(c),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('添加词'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: '查词'),
            NavigationDestination(
                icon: Icon(Icons.menu_book_outlined), label: '我的词库'),
            NavigationDestination(
                icon: Icon(Icons.account_tree_outlined), label: '词汇网络'),
          ],
        ),
      );

  Widget _home(BuildContext c) => ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '柯林斯 V3',
            style: Theme.of(c)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(widget.loading
              ? '正在加载本地词典……'
              : '本地词典已加载 · ${widget.dict.length} 个词条'),
          const SizedBox(height: 18),
          TextField(
            controller: q,
         
