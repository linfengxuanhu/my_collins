import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main()=>runApp(const App());

class Entry{
  final String word,definition;
  Entry(this.word,this.definition);
  factory Entry.fromJson(Map<String,dynamic> j)=>Entry(j['word']??'',j['definition']??'');
}
class Word{
  String word,source,definition,example,note; int status;
  Word({required this.word,this.source='',this.definition='',this.example='',this.note='',this.status=0});
  Map<String,dynamic> toJson()=>{'word':word,'source':source,'definition':definition,'example':example,'note':note,'status':status};
  factory Word.fromJson(Map<String,dynamic> j)=>Word(word:j['word']??'',source:j['source']??'',definition:j['definition']??'',example:j['example']??'',note:j['note']??'',status:j['status']??0);
}

class App extends StatefulWidget{const App({super.key});@override State<App> createState()=>_AppState();}
class _AppState extends State<App>{
 List<Word> words=[]; List<Entry> dict=[]; bool loading=true;
 @override void initState(){super.initState();load();}
 Future<void> load()async{
  final p=await SharedPreferences.getInstance();
  final s=p.getString('words');
  if(s!=null) words=(jsonDecode(s)as List).map((x)=>Word.fromJson(x)).toList();
  try{
   final b=await rootBundle.load('assets/dictionary.json.gz');
   final raw=GZipCodec().decode(b.buffer.asUint8List());
   dict=(jsonDecode(utf8.decode(raw))as List).map((x)=>Entry.fromJson(x)).toList();
  }catch(_){}
  setState(()=>loading=false);
 }
 Future<void> save()async{final p=await SharedPreferences.getInstance();await p.setString('words',jsonEncode(words.map((x)=>x.toJson()).toList()));}
 void add(Word w){
  final i=words.indexWhere((x)=>x.word.toLowerCase()==w.word.toLowerCase());
  setState(() {
   if(i<0){
    words.add(w);
   }else{
    final old=words[i];
    words[i]=Word(word:old.word,source:w.source.isNotEmpty?w.source:old.source,definition:w.definition.isNotEmpty?w.definition:old.definition,example:w.example.isNotEmpty?w.example:old.example,note:old.note,status:old.status);
   }
  });
  save();
 }
 void status(Word w,int s){setState(()=>w.status=s);save();}
 @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'我的柯林斯',theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo),home:Home(words:words,dict:dict,loading:loading,add:add,status:status));
}

class Home extends StatefulWidget{
 final List<Word> words; final List<Entry> dict; final bool loading;
 final void Function(Word) add; final void Function(Word,int) status;
 const Home({super.key,required this.words,required this.dict,required this.loading,required this.add,required this.status});
 @override State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home>{
 int tab=0; final q=TextEditingController();
 @override Widget build(BuildContext c)=>Scaffold(
 appBar:AppBar(title:const Text('我的柯林斯')),
 body:tab==0?_home(c):tab==1?_library(c):_tree(c),
 floatingActionButton:FloatingActionButton.extended(onPressed:_add,icon:const Icon(Icons.add),label:const Text('添加词')),
 bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[
  NavigationDestination(icon:Icon(Icons.search),label:'查词'),
  NavigationDestination(icon:Icon(Icons.menu_book_outlined),label:'我的词库')]));
 Widget _home(BuildContext c)=>ListView(padding:const EdgeInsets.all(18),children:[
  Text('柯林斯 V3',style:Theme.of(c).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
  const SizedBox(height:6),
  Text(widget.loading?'正在加载本地词典……':'本地词典已加载 · ${widget.dict.length} 个词条'),
  const SizedBox(height:18),
  TextField(controller:q,onSubmitted:_search,decoration:const InputDecoration(hintText:'输入单词，例如 boy',prefixIcon:Icon(Icons.search),border:OutlineInputBorder())),
  const SizedBox(height:18),
  Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('${widget.words.length}',style:Theme.of(c).textTheme.displaySmall),const Text('我的词条'),
   const SizedBox(height:12),
   Wrap(spacing:8,children:List.generate(4,(i)=>Chip(label:Text('${['待抄','已抄','已描','已掌握'][i]} ${widget.words.where((w)=>w.status==i).length}'))))
  ]))),
  const SizedBox(height:12),
  const Text('操作提示：查到一个词后，可以加入“我的词库”，并填写它是从哪个词里发现的。')
 ]);
 Widget _library(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:widget.words.map((w)=>_tile(c,w)).toList());
 Widget _tree(BuildContext c)=>ListView(padding:const EdgeInsets.all(12),children:[
  Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Text('我的词汇网络',style:Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
   const SizedBox(height:6),
   const Text('点击词条可以继续进入 V3；缩进表示“由这个词发现”。'),
  ]))),
  ..._roots().map((w)=>_treeNode(c,w,0,<String>{})),
  if(widget.words.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('还没有词条。先查一个词加入词库吧。'))
 ]);
 List<Word> _roots()=>widget.words.where((w)=>w.source.trim().isEmpty || !widget.words.any((x)=>x.word.toLowerCase()==w.source.toLowerCase())).toList();
 Widget _treeNode(BuildContext c,Word w,int level,Set<String> path){
  final key=w.word.toLowerCase();
  if(path.contains(key))return const SizedBox.shrink();
  final next={...path,key};
  final kids=widget.words.where((x)=>x.source.toLowerCase()==key).toList();
  final entry=widget.dict.where((e)=>e.word.toLowerCase()==key).firstOrNull ?? Entry(w.word,w.definition);
  return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
   Padding(padding:EdgeInsets.only(left:level*18),child:Card(child:ListTile(
    dense:true, leading:CircleAvatar(radius:15,child:Text('${level+1}')),
    title:Text(w.word,style:const TextStyle(fontWeight:FontWeight.w600)),
    subtitle:Text('${w.source.isEmpty?'种子词':'来自：${w.source}'} · ${['待抄','已抄','已描','已掌握'][w.status]}'),
    trailing:Icon(kids.isEmpty?Icons.chevron_right:Icons.account_tree_outlined),
    onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>DictPage(entry:entry,all:widget.words,add:widget.add,status:widget.status,dict:widget.dict,sourceWord:w.source))),
   ))),
   ...kids.map((x)=>_treeNode(c,x,level+1,next))
  ]);
 }
 Widget _tile(BuildContext c,Word w)=>Card(child:ListTile(
  title:Text(w.word,style:const TextStyle(fontWeight:FontWeight.w600)),
  subtitle:Text('${w.source.isEmpty?'种子词':'来自：${w.source}'} · ${['待抄','已抄','已描','已掌握'][w.status]}'),
  trailing:const Icon(Icons.chevron_right),
  onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Detail(w:w,all:widget.words,dict:widget.dict,add:widget.add,status:widget.status)))));
 void _search(String x){
  final query=x.trim().toLowerCase(); if(query.isEmpty)return;
  final exact=widget.dict.where((e)=>e.word.toLowerCase()==query).toList();
  final starts=widget.dict.where((e)=>e.word.toLowerCase().startsWith(query)).take(30).toList();
  Navigator.push(context,MaterialPageRoute(builder:(_)=>Results(query:query,exact:exact.isEmpty?null:exact.first,starts:starts,all:widget.words,add:widget.add,status:widget.status,dict:widget.dict)));
 }
 void _add()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Add(add:widget.add)));
}

class Results extends StatelessWidget{
 final String query;final Entry? exact;final List<Entry> starts;final List<Word> all;final void Function(Word) add;final void Function(Word,int) status;final List<Entry> dict;
 const Results({super.key,required this.query,required this.exact,required this.starts,required this.all,required this.add,required this.status,required this.dict});
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(query)),body:ListView(padding:const EdgeInsets.all(12),children:[
  if(exact!=null) _card(c,exact!,true),
  if(starts.isNotEmpty) ...[const Padding(padding:EdgeInsets.all(8),child:Text('相关词条',style:TextStyle(fontWeight:FontWeight.bold))),...starts.where((x)=>exact==null||x.word!=exact!.word).map((x)=>_card(c,x,false))],
  if(exact==null&&starts.isEmpty)const Padding(padding:EdgeInsets.all(24),child:Text('本地词典没有找到这个词。'))
 ]));
 Widget _card(BuildContext c,Entry e,bool big)=>Card(child:ListTile(
  title:Text(e.word,style:TextStyle(fontSize:big?24:18,fontWeight:FontWeight.w600)),
  subtitle:Text(e.definition,maxLines:big?12:3,overflow:TextOverflow.ellipsis),
  onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>DictPage(entry:e,all:all,add:add,status:status,dict:dict)))));
}

class DictPage extends StatelessWidget{
 final Entry entry;final List<Word> all;final void Function(Word) add;final void Function(Word,int) status;final List<Entry> dict;
 // sourceWord 表示：这个词是从哪个释义里点出来的。这样一键加入时会自动建立父子关系。
 final String sourceWord;
 const DictPage({super.key,required this.entry,required this.all,required this.add,required this.status,required this.dict,this.sourceWord=''});
 @override Widget build(BuildContext c){
  final mine=all.where((w)=>w.word.toLowerCase()==entry.word.toLowerCase()).firstOrNull;
  return Scaffold(appBar:AppBar(title:Text(entry.word)),body:ListView(padding:const EdgeInsets.all(18),children:[
   Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(child:Text(entry.word,style:Theme.of(c).textTheme.displaySmall?.copyWith(fontWeight:FontWeight.bold))),
    if(sourceWord.isNotEmpty)Chip(label:Text('来自 $sourceWord')),
   ]),
   const SizedBox(height:14),
   Card(child:Padding(padding:const EdgeInsets.all(16),child:_ClickableDefinition(text:entry.definition,currentWord:entry.word,all:all,dict:dict,add:add,status:status))),
   const SizedBox(height:12),
   FilledButton.icon(onPressed:(){
     add(Word(word:entry.word,source:sourceWord,definition:entry.definition));
     ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(sourceWord.isEmpty?'已加入我的词库':'已加入我的词库 · 来源：$sourceWord')));
   },icon:Icon(mine==null?Icons.bookmark_add:Icons.bookmark),label:Text(mine==null?'一键加入我的词库':(sourceWord.isEmpty?'再次保存':'一键加入 / 更新来源'))),
   if(mine!=null) ...[
    const SizedBox(height:10),
    Text('学习状态',style:Theme.of(c).textTheme.titleMedium),
    Wrap(spacing:8,children:List.generate(4,(i)=>ChoiceChip(label:Text(['待抄','已抄','已描','已掌握'][i]),selected:mine.status==i,onSelected:(_)=>status(mine,i))))
   ]
  ]));
 }
}

/// 把 V3 释义中的英文词切成可点击的小词块。
/// 点击任意英文词：先在本地 V3 精确查找；找到后直接进入该词条，并可一键加入。
class _ClickableDefinition extends StatelessWidget{
 final String text,currentWord;final List<Word> all;final List<Entry> dict;final void Function(Word) add;final void Function(Word,int) status;
 const _ClickableDefinition({required this.text,required this.currentWord,required this.all,required this.dict,required this.add,required this.status});
 @override Widget build(BuildContext c){
  final re=RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)?(?:-[A-Za-z]+(?:['’][A-Za-z]+)?)?");
  final matches=re.allMatches(text).toList();
  if(matches.isEmpty)return SelectableText(text,style:const TextStyle(fontSize:16,height:1.45));
  final spans=<InlineSpan>[];int pos=0;
  for(final m in matches){
    if(m.start>pos)spans.add(TextSpan(text:text.substring(pos,m.start)));
    final token=m.group(0)!;
    final clean=token.toLowerCase();
    final found=dict.where((e)=>e.word.toLowerCase()==clean).firstOrNull;
    if(found==null || clean==currentWord.toLowerCase()){
      spans.add(TextSpan(text:token,style:const TextStyle(fontSize:16,height:1.45)));
    }else{
      spans.add(TextSpan(text:token,style:const TextStyle(fontSize:16,height:1.45,decoration:TextDecoration.underline),recognizer:TapGestureRecognizer()..onTap=(){
        Navigator.push(c,MaterialPageRoute(builder:(_)=>DictPage(entry:found,all:all,add:add,status:status,dict:dict,sourceWord:currentWord)));
      }));
    }
    pos=m.end;
  }
  if(pos<text.length)spans.add(TextSpan(text:text.substring(pos)));
  return SelectableText.rich(TextSpan(style:DefaultTextStyle.of(c).style.copyWith(fontSize:16,height:1.45),children:spans));
 }
}

class Add extends StatefulWidget{final void Function(Word) add;const Add({super.key,required this.add});@override State<Add> createState()=>_AddState();}
class _AddState extends State<Add>{
 final a=List.generate(5,(_)=>TextEditingController());final labels=['单词 *','来源词（例如 boy）','释义','例句','笔记'];
 @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('添加词条')),body:ListView(padding:const EdgeInsets.all(18),children:[
  ...List.generate(5,(i)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:a[i],maxLines:i>=2?3:1,decoration:InputDecoration(labelText:labels[i],border:const OutlineInputBorder())))),
  FilledButton.icon(onPressed:(){if(a[0].text.trim().isEmpty)return;add(Word(word:a[0].text.trim(),source:a[1].text.trim(),definition:a[2].text.trim(),example:a[3].text.trim(),note:a[4].text.trim()));Navigator.pop(c);},icon:const Icon(Icons.save),label:const Text('保存'))
 ]));
}
class Detail extends StatelessWidget{
 final Word w;final List<Word> all;final List<Entry> dict;final void Function(Word) add;final void Function(Word,int) status;
 const Detail({super.key,required this.w,required this.all,required this.dict,required this.add,required this.status});
 @override Widget build(BuildContext c){
  final kids=all.where((x)=>x.source.toLowerCase()==w.word.toLowerCase()).toList();
  return Scaffold(appBar:AppBar(title:Text(w.word)),body:ListView(padding:const EdgeInsets.all(18),children:[
   Text(w.word,style:Theme.of(c).textTheme.displaySmall?.copyWith(fontWeight:FontWeight.bold)),
   if(w.source.isNotEmpty)Text('← 发现于：${w.source}'),
   const SizedBox(height:16),_box(c,'释义',w.definition),_box(c,'例句',w.example),_box(c,'笔记',w.note),
   const SizedBox(height:8),Text('学习状态',style:Theme.of(c).textTheme.titleMedium),
   Wrap(spacing:8,children:List.generate(4,(i)=>ChoiceChip(label:Text(['待抄','已抄','已描','已掌握'][i]),selected:w.status==i,onSelected:(_)=>status(w,i)))),
   const SizedBox(height:18),Text('由它发现的词',style:Theme.of(c).textTheme.titleMedium),
   if(kids.isEmpty)const Text('暂无'),
   ...kids.map((x)=>ListTile(title:Text(x.word),subtitle:Text(['待抄','已抄','已描','已掌握'][x.status]),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Detail(w:x,all:all,dict:dict,add:add,status:status)))))
 ]));
 Widget _box(BuildContext c,String t,String s)=>Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(t,style:Theme.of(c).textTheme.titleMedium),const SizedBox(height:8),SelectableText(s.isEmpty?'暂未录入':s)])));
}
extension FirstOrNull<T> on Iterable<T>{T? get firstOrNull=>isEmpty?null:first;}


// ===== V5: 抄词/描红练习 =====
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
                        Text(w.word,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            )),
                        const SizedBox(height: 8),
                        Text(w.definition.isEmpty ? '（暂无释义）' : w.definition,
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, color: Colors.black54)),
                        const SizedBox(height: 18),
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            '${w.word}    ${w.word}    ${w.word}',
                            style: TextStyle(
                              fontSize: 25,
                              letterSpacing: 1.0,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade400),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}


// ===== V6: 今日抄词 =====
class DailyCopyPage extends StatefulWidget {
  final List<Word> words;
  const DailyCopyPage({super.key, required this.words});

  @override
  State<DailyCopyPage> createState() => _DailyCopyPageState();
}

class _DailyCopyPageState extends State<DailyCopyPage> {
  int count = 10;
  late List<Word> today;

  @override
  void initState() {
    super.initState();
    today = _pickToday();
  }

  List<Word> _pickToday() {
    final list = [...widget.words];
    list.sort((a, b) {
      final sa = a.status == 0 ? 0 : 1;
      final sb = b.status == 0 ? 0 : 1;
      return sa.compareTo(sb);
    });
    return list.take(count).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('今日抄词'),
        actions: [
          IconButton(
            tooltip: '今日抄词',
            icon: const Icon(Icons.today),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DailyCopyPage(words: widget.words),
                ),
              );
            },
          ),

          PopupMenuButton<int>(
            onSelected: (v) {
              setState(() {
                count = v;
                today = _pickToday();
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
                            Chip(label: Text(['未学习','已抄','已描','已掌握'][w.status.clamp(0,3).toInt()])),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (w.source.isNotEmpty)
                          Text('发现于：${w.source}',
                              style: const TextStyle(color: Colors.blueGrey)),
                        const SizedBox(height: 10),
                        Text(
                          w.definition.isEmpty ? '暂无释义' : w.definition,
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${w.word}    ${w.word}',
                          style: TextStyle(
                            fontSize: 25,
                            letterSpacing: 1,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const Divider(height: 22),
                        const SizedBox(height: 22),
                        const Divider(),
                        const SizedBox(height: 22),
                        const Divider(),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          setState(() {
            today = _pickToday();
          });
        },
        icon: const Icon(Icons.refresh),
        label: const Text('重新抽取'),
      ),
    );
  }
}


// ===== V7: COBUILD 学习卡 =====
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
        .split(RegExp(r'(?:(?:\n+)|(?:\s*;\s*)|(?:\s{2,}))'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return parts.isEmpty ? [text.trim()] : parts.take(12).toList();
  }

  String _guessPos(String text) {
    final m = RegExp(r'\b(noun|verb|adjective|adverb|pronoun|preposition|conjunction|determiner|modal|auxiliary)\b',
            caseSensitive: false)
        .firstMatch(text);
    return m?.group(1) ?? '词性待确认';
  }

  @override
  Widget build(BuildContext context) {
    final meanings = _splitMeanings(widget.word.definition);
    final current = meanings[meaning.clamp(0, meanings.length - 1).toInt()];
    return Scaffold(
      appBar: AppBar(title: Text(widget.word.word)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.word.word,
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(children: [
            Chip(label: Text(_guessPos(widget.word.definition))),
            const SizedBox(width: 8),
            Chip(label: Text(['未学习','已抄','已描','已掌握'][widget.word.status.clamp(0,3).toInt()])),
          ]),
          const SizedBox(height: 18),
          const Text('COBUILD V3 释义',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(current, style: const TextStyle(fontSize: 17, height: 1.55)),
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
                  selected: i == meaning,
                  onSelected: (_) => setState(() => meaning = i),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (widget.word.example.isNotEmpty) ...[
            const Text('例句',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.word.example,
                    style: const TextStyle(fontSize: 16, height: 1.5)),
              ),
            ),
          ],
          if (widget.word.source.isNotEmpty) ...[
            const SizedBox(height: 18),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_tree),
              title: const Text('发现来源'),
              subtitle: Text('这个词是从「${widget.word.source}」的释义中发现的'),
            ),
          ],
          const SizedBox(height: 18),
          const Text('抄写',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.grey.shade400)),
                ),
                alignment: Alignment.bottomLeft,
                child: Text(
                  widget.word.word,
                  style: TextStyle(fontSize: 24, color: Colors.grey.shade400),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
