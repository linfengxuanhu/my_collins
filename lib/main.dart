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
    final i = words
        .indexWhere((x) => x.word.toLowerCase() == w.word.toLowerCase());
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
    final i = words
        .indexWhere((x) => x.word.toLowerCase() == w.word.toLowerCase());
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

  Widget _home(BuildContext c) {
    return ListView(
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
          onSubmitted: _search,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '输入单词，例如 boy',
            prefixIcon: Icon(Icons.search),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.words.length}',
                    style: Theme.of(c).textTheme.displaySmall),
                const Text('我的词条'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    4,
                    (i) => Chip(
                      label: Text(
                        '${kStatusLabels[i]} ${widget.words.where((w) => w.status == i).length}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('操作提示：查到一个词后，可以加入“我的词库”，并填写它是从哪个词里发现的。'),
      ],
    );
  }

  Widget _library(BuildContext c) {
    if (widget.words.isEmpty) {
      return const Center(child: Text('还没有词条。先查一个词加入词库吧。'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: widget.words.map((w) => _tile(c, w)).toList(),
    );
  }

  Widget _tree(BuildContext c) {
    final roots = _roots();
    final orphans = <Word>[];
    for (final w in widget.words) {
      if (!_reachableFromRoots(w, roots)) orphans.add(w);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的词汇网络',
                  style: Theme.of(c)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text('点击词条可以继续进入 V3；缩进表示“由这个词发现”。'),
              ],
            ),
          ),
        ),
        ...roots.map((w) => _treeNode(c, w, 0, <String>{})),
        if (orphans.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('互引 / 孤立词条',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          ...orphans.map((w) => _treeNode(c, w, 0, <String>{}, forced: true)),
        ],
        if (widget.words.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('还没有词条。先查一个词加入词库吧。'),
          ),
      ],
    );
  }

  List<Word> _roots() {
    return widget.words
        .where((w) =>
            w.source.trim().isEmpty ||
            !widget.words
                .any((x) => x.word.toLowerCase() == w.source.toLowerCase()))
        .toList();
  }

  bool _reachableFromRoots(Word w, List<Word> roots) {
    final visited = <String>{};

    bool walk(Word cur) {
      final key = cur.word.toLowerCase();
      if (!visited.add(key)) return false;
      for (final r in roots) {
        if (r.word.toLowerCase() == key) return true;
      }
      final parentKey = cur.source.toLowerCase();
      if (parentKey.isEmpty) return false;
      Word? parent;
      for (final x in widget.words) {
        if (x.word.toLowerCase() == parentKey) {
          parent = x;
          break;
        }
      }
      if (parent == null) return false;
      return walk(parent);
    }

    return walk(w);
  }

  Widget _treeNode(
    BuildContext c,
    Word w,
    int level,
    Set<String> path, {
    bool forced = false,
  }) {
    final key = w.word.toLowerCase();
    if (path.contains(key) && !forced) return const SizedBox.shrink();
    final next = {...path, key};
    final kids = widget.words
        .where((x) =>
            x.source.toLowerCase() == key && x.word.toLowerCase() != key)
        .toList();
    final entry = widget.dictIndex[key] ?? Entry(w.word, w.definition);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: level * 18.0),
          child: Card(
            child: ListTile(
              dense: true,
              leading: CircleAvatar(radius: 15, child: Text('${level + 1}')),
              title: Text(w.word,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                '${w.source.isEmpty ? '种子词' : '来自：${w.source}'} · ${kStatusLabels[w.status.clamp(0, 3)]}',
              ),
              trailing: Icon(kids.isEmpty
                  ? Icons.chevron_right
                  : Icons.account_tree_outlined),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => DictPage(
                    entry: entry,
                    all: widget.words,
                    add: widget.add,
                    setStatus: widget.setStatus,
                    dictIndex: widget.dictIndex,
                    sourceWord: w.source,
                  ),
                ),
              ),
            ),
          ),
        ),
        ...kids.map((x) => _treeNode(c, x, level + 1, next)),
      ],
    );
  }

  Widget _tile(BuildContext c, Word w) {
    return Card(
      child: ListTile(
        title:
            Text(w.word, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          '${w.source.isEmpty ? '种子词' : '来自：${w.source}'} · ${kStatusLabels[w.status.clamp(0, 3)]}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(
          c,
          MaterialPageRoute(
            builder: (_) => Detail(
              word: w,
              all: widget.words,
              dictIndex: widget.dictIndex,
              add: widget.add,
              setStatus: widget.setStatus,
            ),
          ),
        ),
      ),
    );
  }

  void _search(String x) {
    final query = x.trim().toLowerCase();
    if (query.isEmpty) return;
    final exact = widget.dictIndex[query];
    final starts = widget.dict
        .where((e) => e.word.toLowerCase().startsWith(query))
        .take(30)
        .toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Results(
          query: query,
          exact: exact,
          starts: starts,
          all: widget.words,
          add: widget.add,
          setStatus: widget.setStatus,
          dictIndex: widget.dictIndex,
        ),
      ),
    );
  }

  void _add() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Add(add: widget.add)),
    );
  }
}

// ============================================================
// 搜索结果
// ============================================================
class Results extends StatelessWidget {
  final String query;
  final Entry? exact;
  final List<Entry> starts;
  final List<Word> all;
  final void Function(Word) add;
  final void Function(Word, int) setStatus;
  final Map<String, Entry> dictIndex;

  const Results({
    super.key,
    required this.query,
    required this.exact,
    required this.starts,
    required this.all,
    required this.add,
    required this.setStatus,
    required this.dictIndex,
  });

  @override
  Widget build(BuildContext c) {
    final exactKey = exact?.word.toLowerCase();
    final others = starts
        .where((x) => exactKey == null || x.word.toLowerCase() != exactKey)
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(query)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (exact != null) _card(c, exact!, true),
          if (others.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('相关词条',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...others.map((x) => _card(c, x, false)),
          ],
          if (exact == null && others.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('本地词典没有找到这个词。'),
            ),
        ],
      ),
    );
  }

  Widget _card(BuildContext c, Entry e, bool big) {
    return Card(
      child: ListTile(
        title: Text(
          e.word,
          style: TextStyle(
              fontSize: big ? 24 : 18, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          e.definition,
          maxLines: big ? 12 : 3,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: () => Navigator.push(
          c,
          MaterialPageRoute(
            builder: (_) => DictPage(
              entry: e,
              all: all,
              add: add,
              setStatus: setStatus,
              dictIndex: dictIndex,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// 词典详情页
// ============================================================
class DictPage extends StatefulWidget {
  final Entry entry;
  final List<Word> all;
  final void Function(Word) add;
  final void Function(Word, int) setStatus;
  final Map<String, Entry> dictIndex;
  final String sourceWord;

  const DictPage({
    super.key,
    required this.entry,
    required this.all,
    required this.add,
    required this.setStatus,
    required this.dictIndex,
    this.sourceWord = '',
  });

  @override
  State<DictPage> createState() => _DictPageState();
}

class _DictPageState extends State<DictPage> {
  Word? _findMine() {
    final key = widget.entry.word.toLowerCase();
    for (final w in widget.all) {
      if (w.word.toLowerCase() == key) return w;
    }
    return null;
  }

  @override
  Widget build(BuildContext c) {
    final mine = _findMine();

    return Scaffold(
      appBar: AppBar(title: Text(widget.entry.word)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.entry.word,
                  style: Theme.of(c)
                      .textTheme
                      .displaySmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (widget.sourceWord.isNotEmpty)
                Chip(label: Text('来自 ${widget.sourceWord}')),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _ClickableDefinition(
                text: widget.entry.definition,
                currentWord: widget.entry.word,
                all: widget.all,
                dictIndex: widget.dictIndex,
                add: widget.add,
                setStatus: widget.setStatus,
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {
              widget.add(Word(
                word: widget.entry.word,
                source: widget.sourceWord,
                definition: widget.entry.definition,
              ));
              setState(() {});
              ScaffoldMessenger.of(c).showSnackBar(
                SnackBar(
                  content: Text(widget.sourceWord.isEmpty
                      ? '已加入我的词库'
                      : '已加入我的词库 · 来源：${widget.sourceWord}'),
                ),
              );
            },
            icon: Icon(mine == null ? Icons.bookmark_add : Icons.bookmark),
            label: Text(
              mine == null
                  ? '一键加入我的词库'
                  : (widget.sourceWord.isEmpty ? '再次保存' : '一键加入 / 更新来源'),
            ),
          ),
          if (mine != null) ...[
            const SizedBox(height: 10),
            Text('学习状态', style: Theme.of(c).textTheme.titleMedium),
            Wrap(
              spacing: 8,
              children: List.generate(
                4,
                (i) => ChoiceChip(
                  label: Text(kStatusLabels[i]),
                  selected: mine.status == i,
                  onSelected: (_) {
                    widget.setStatus(mine!, i);
                    setState(() {});
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// 可点击释义
// ============================================================
class _ClickableDefinition extends StatelessWidget {
  final String text, currentWord;
  final List<Word> all;
  final Map<String, Entry> dictIndex;
  final void Function(Word) add;
  final void Function(Word, int) setStatus;

  const _ClickableDefinition({
    required this.text,
    required this.currentWord,
    required this.all,
    required this.dictIndex,
    required this.add,
    required this.setStatus,
  });

  @override
  Widget build(BuildContext c) {
    final re = RegExp(
      r"[A-Za-z]+(?:['’][A-Za-z]+)?(?:-[A-Za-z]+(?:['’][A-Za-z]+)?)?",
    );
    final matches = re.allMatches(text).toList();
    if (matches.isEmpty) {
      return SelectableText(text,
          style: const TextStyle(fontSize: 16, height: 1.45));
    }
    final spans = <InlineSpan>[];
    int pos = 0;
    final curLower = currentWord.toLowerCase();
    for (final m in matches) {
      if (m.start > pos) {
        spans.add(TextSpan(text: text.substring(pos, m.start)));
      }
      final token = m.group(0)!;
      final clean = token.toLowerCase();
      final found = dictIndex[clean];
      if (found == null || clean == curLower) {
        spans.add(TextSpan(
          text: token,
          style: const TextStyle(fontSize: 16, height: 1.45),
        ));
      } else {
        spans.add(TextSpan(
          text: token,
          style: const TextStyle(
            fontSize: 16,
            height: 1.45,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => DictPage(
                    entry: found,
                    all: all,
                    add: add,
                    setStatus: setStatus,
                    dictIndex: dictIndex,
                    sourceWord: currentWord,
                  ),
                ),
              );
            },
        ));
      }
      pos = m.end;
    }
    if (pos < text.length) {
      spans.add(TextSpan(text: text.substring(pos)));
    }
    return SelectableText.rich(
      TextSpan(
        style:
            DefaultTextStyle.of(c).style.copyWith(fontSize: 16, height: 1.45),
        children: spans,
      ),
    );
  }
}

// ============================================================
// 添加词条
// ============================================================
class Add extends StatefulWidget {
  final void Function(Word) add;
  const Add({super.key, required this.add});
  @override
  State<Add> createState() => _AddState();
}

class _AddState extends State<Add> {
  final a = List.generate(5, (_) => TextEditingController());
  final labels = ['单词 *', '来源词（例如 boy）', '释义', '例句', '笔记'];

  @override
  void dispose() {
    for (final ctl in a) {
      ctl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      appBar: AppBar(title: const Text('添加词条')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          ...List.generate(
            5,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: a[i],
                maxLines: i >= 2 ? 3 : 1,
                decoration: InputDecoration(
                  labelText: labels[i],
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              if (a[0].text.trim().isEmpty) return;
              widget.add(Word(
                word: a[0].text.trim(),
                source: a[1].text.trim(),
                definition: a[2].text.trim(),
                example: a[3].text.trim(),
                note: a[4].text.trim(),
              ));
              Navigator.pop(c);
            },
            icon: const Icon(Icons.save),
            label: const Text('保存'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 词条详情
// ============================================================
class Detail extends StatelessWidget {
  final Word word;
  final List<Word> all;
  final Map<String, Entry> dictIndex;
  final void Function(Word) add;
  final void Function(Word, int) setStatus;

  const Detail({
    super.key,
    required this.word,
    required this.all,
    required this.dictIndex,
    required this.add,
    required this.setStatus,
  });

  Word _latest() {
    final key = word.word.toLowerCase();
    for (final x in all) {
      if (x.word.toLowerCase() == key) return x;
    }
    return word;
  }

  @override
  Widget build(BuildContext c) {
    final w = _latest();
    final key = w.word.toLowerCase();
    final kids = all.where((x) => x.source.toLowerCase() == key).toList();

    return Scaffold(
      appBar: AppBar(title: Text(w.word)),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            w.word,
            style: Theme.of(c)
                .textTheme
                .displaySmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (w.source.isNotEmpty) Text('← 发现于：${w.source}'),
          const SizedBox(height: 16),
          _box(c, '释义', w.definition),
          _box(c, '例句', w.example),
          _box(c, '笔记', w.note),
          const SizedBox(height: 8),
          Text('学习状态', style: Theme.of(c).textTheme.titleMedium),
          Wrap(
            spacing: 8,
            children: List.generate(
              4,
              (i) => ChoiceChip(
                label: Text(kStatusLabels[i]),
                selected: w.status == i,
                onSelected: (_) => setStatus(w, i),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('由它发现的词', style: Theme.of(c).textTheme.titleMedium),
          if (kids.isEmpty) const Text('暂无'),
          ...kids.map(
            (x) => ListTile(
              title: Text(x.word),
              subtitle: Text(kStatusLabels[x.status.clamp(0, 3)]),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(
                  builder: (_) => Detail(
                    word: x,
                    all: all,
                    dictIndex: dictIndex,
                    add: add,
                    setStatus: setStatus,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(BuildContext c, String t, String s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 8),
            SelectableText(s.isEmpty ? '暂未录入' : s),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 抄写行
// ============================================================
class _CopyLine extends StatelessWidget {
  final String template;
  const _CopyLine({required this.template});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
      ),
      child: Stack(
        children: [
          if (template.isNotEmpty)
            Positioned.fill(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    template,
                    style: TextStyle(
                      fontSize: 25,
                      letterSpacing: 1.0,
                      color: Colors.grey.shade300,
                    ),
                  ),
                ),
              ),
            ),
          const Positioned.fill(
            child: TextField(
              maxLines: 1,
              style: TextStyle(fontSize: 25, letterSpacing: 1.0),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.only(bottom: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// V5: 抄词练习
// ============================================================
class CopyWorksheetPage extends StatelessWidget {
  final List<Word> words;
  const CopyWorksheetPage({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    final selected = words.take(20).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('抄词练习')),
      body: selected.isEmpty
          ? const Center(child: Text('词库里还没有词，先加入几个词吧。'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: selected.length,
              itemBuilder: (context, i) {
                final w = selected[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          w.word,
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          w.definition.isEmpty ? '（暂无释义）' : w.definition,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 18),
                        _CopyLine(template: '${w.word}    ${w.word}'),
                        const SizedBox(height: 10),
                        const _CopyLine(template: ''),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================
// V6: 今日抄词
// ============================================================
class DailyCopyPage extends StatefulWidget {
  final List<Word> words;
  const DailyCopyPage({super.key, required this.words});

  @override
  State<DailyCopyPage> createState() => _DailyCopyPageState();
}

class _DailyCopyPageState extends State<DailyCopyPage> {
  int count = 10;
  List<Word> today = [];
  final _rand = Random();

  @override
  void initState() {
    super.initState();
    _pickToday();
  }

  void _pickToday() {
    final pool = [...widget.words];
    pool.shuffle(_rand);
    pool.sort((a, b) {
      final sa = a.status == 0 ? 0 : 1;
      final sb = b.status == 0 ? 0 : 1;
      return sa.compareTo(sb);
    });
    today = pool.take(count).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日抄词'),
        actions: [
          PopupMenuButton<int>(
            tooltip: '每日数量',
            onSelected: (v) {
              setState(() {
                count = v;
                _pickToday();
              });
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 5, child: Text('每天 5 词')),
              PopupMenuItem(value: 10, child: Text('每天 10 词')),
              PopupMenuItem(value: 20, child: Text('每天 20 词')),
            ],
          ),
        ],
      ),
      body: today.isEmpty
          ? const Center(child: Text('先从 V3 词典加入一些词。'))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: today.length,
              itemBuilder: (_, i) {
                final w = today[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${i + 1}. ${w.word}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Chip(
                              label:
                                  Text(kStatusLabels[w.status.clamp(0, 3)]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (w.source.isNotEmpty)
                          Text(
                            '发现于：${w.source}',
                            style: const TextStyle(color: Colors.blueGrey),
                          ),
                        const SizedBox(height: 10),
                        Text(
                          w.definition.isEmpty ? '暂无释义' : w.definition,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        _CopyLine(template: '${w.word}    ${w.word}'),
                        const SizedBox(height: 10),
                        const _CopyLine(template: ''),
                        const SizedBox(height: 10),
                        const _CopyLine(template: ''),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => setState(_pickToday),
        icon: const Icon(Icons.refresh),
        label: const Text('重新抽取'),
      ),
    );
  }
}

// ============================================================
// V7: COBUILD 学习卡
// ============================================================
class CobuildStudyCardPage extends StatefulWidget {
  final Word word;
  const CobuildStudyCardPage({super.key, required this.word});

  @override
  State<CobuildStudyCardPage> createState() => _CobuildStudyCardPageState();
}

class _CobuildStudyCardPageState extends State<CobuildStudyCardPage> {
  int meaning = 0;

  List<String> _splitMeanings(String text) {
    if (text.trim().isEmpty) return ['暂无释义'];
    final parts = text
        .split(RegExp(r'(?:\n+)|(?:\s*;\s*)'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? [text.trim()] : parts.take(12).toList();
  }

  String _guessPos(String text) {
    final m = RegExp(
      r'\b(noun|verb|adjective|adverb|pronoun|preposition|conjunction|determiner|modal|auxiliary)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return m?.group(1) ?? '词性待确认';
  }

  @override
  Widget build(BuildContext context) {
    final meanings = _splitMeanings(widget.word.definition);
    final idx = meaning.clamp(0, meanings.length - 1);
    final current = meanings[idx];
    return Scaffold(
      appBar: AppBar(title: Text(widget.word.word)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.word.word,
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Chip(label: Text(_guessPos(widget.word.definition))),
              const SizedBox(width: 8),
              Chip(
                label: Text(kStatusLabels[widget.word.status.clamp(0, 3)]),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'COBUILD V3 释义',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                current,
                style: const TextStyle(fontSize: 17, height: 1.55),
              ),
            ),
          ),
          if (meanings.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: List.generate(
                meanings.length,
                (i) => ChoiceChip(
                  label: Text('义项 ${i + 1}'),
                  selected: i == idx,
                  onSelected: (_) => setState(() => meaning = i),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (widget.word.example.isNotEmpty) ...[
            const Text(
              '例句',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  widget.word.example,
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),
              ),
            ),
          ],
          if (widget.word.source.isNotEmpty) ...[
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_tree),
              title: const Text('发现来源'),
              subtitle:
                  Text('这个词是从「${widget.word.source}」的释义中发现的'),
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            '抄写',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CopyLine(template: widget.word.word),
            ),
          ),
        ],
      ),
    );
  }
}
