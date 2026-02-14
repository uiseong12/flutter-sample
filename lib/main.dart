import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const StoryApp());
}

class StoryApp extends StatelessWidget {
  const StoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '중세 로맨스 연대기',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7A3E3E)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class Character {
  Character({
    required this.name,
    required this.title,
    required this.description,
    required this.favoriteGift,
    required this.imageUrl,
    this.affection = 30,
    this.dates = 0,
    this.gifts = 0,
  });

  final String name;
  final String title;
  final String description;
  final String favoriteGift;
  final String imageUrl;
  int affection;
  int dates;
  int gifts;

  Map<String, dynamic> toJson() => {
        'name': name,
        'title': title,
        'description': description,
        'favoriteGift': favoriteGift,
        'imageUrl': imageUrl,
        'affection': affection,
        'dates': dates,
        'gifts': gifts,
      };

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      name: json['name'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      favoriteGift: json['favoriteGift'] as String,
      imageUrl: json['imageUrl'] as String? ?? '',
      affection: json['affection'] as int? ?? 30,
      dates: json['dates'] as int? ?? 0,
      gifts: json['gifts'] as int? ?? 0,
    );
  }
}

class GearItem {
  GearItem({
    required this.id,
    required this.name,
    required this.description,
    required this.charmBonus,
  });

  final String id;
  final String name;
  final String description;
  final int charmBonus;
}

class StoryEvent {
  StoryEvent({
    required this.title,
    required this.description,
    required this.choices,
    required this.speaker,
    required this.line,
    required this.backgroundUrl,
  });

  final String title;
  final String description;
  final List<StoryChoice> choices;
  final String speaker;
  final String line;
  final String backgroundUrl;

  factory StoryEvent.fromJson(Map<String, dynamic> json) {
    final choices = (json['choices'] as List<dynamic>)
        .map((e) => StoryChoice.fromJson(e as Map<String, dynamic>))
        .toList();

    return StoryEvent(
      title: json['title'] as String,
      description: json['description'] as String,
      choices: choices,
      speaker: json['speaker'] as String? ?? '나레이션',
      line: json['line'] as String? ?? '',
      backgroundUrl: json['backgroundUrl'] as String? ?? '',
    );
  }
}

class StoryChoice {
  StoryChoice({
    required this.label,
    required this.result,
    required this.target,
    required this.affectionDelta,
  });

  final String label;
  final String result;
  final String target;
  final int affectionDelta;

  factory StoryChoice.fromJson(Map<String, dynamic> json) {
    return StoryChoice(
      label: json['label'] as String,
      result: json['result'] as String,
      target: json['target'] as String,
      affectionDelta: json['affectionDelta'] as int,
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _saveKey = 'story_save_v3';

  int _selectedTab = 0;
  int _storyIndex = 0;
  bool _isLoading = true;

  final List<String> _logs = [];

  int _baseCharm = 10;
  String? _equippedItemId;

  final List<GearItem> _gearItems = [
    GearItem(id: 'silver_tiara', name: '은빛 티아라', description: '품위를 더해 첫인상을 높여준다.', charmBonus: 4),
    GearItem(id: 'rose_perfume', name: '장미 향수', description: '가까운 대화에서 매력이 돋보인다.', charmBonus: 6),
    GearItem(id: 'moon_necklace', name: '월광 목걸이', description: '신비로운 분위기로 호감 상승 효과 강화.', charmBonus: 8),
  ];

  final List<Character> _defaultCharacters = [
    Character(
      name: '엘리안',
      title: '왕실 근위대장',
      description: '원칙주의자지만 주인공 앞에서는 묘하게 다정해지는 기사.',
      favoriteGift: '은빛 브로치',
      imageUrl: 'https://api.dicebear.com/9.x/adventurer/png?seed=Elian&backgroundColor=fde68a',
    ),
    Character(
      name: '루시안',
      title: '궁정 마법사',
      description: '차분하고 냉정하지만, 주인공의 재능에 깊은 관심을 보인다.',
      favoriteGift: '고대 마도서 조각',
      imageUrl: 'https://api.dicebear.com/9.x/adventurer/png?seed=Lucian&backgroundColor=c4b5fd',
    ),
  ];

  late List<Character> _characters;
  List<StoryEvent> _events = [];

  int get _equippedCharmBonus {
    final found = _gearItems.where((i) => i.id == _equippedItemId);
    if (found.isEmpty) return 0;
    return found.first.charmBonus;
  }

  int get _totalCharm => _baseCharm + _equippedCharmBonus;

  int _withCharmBonus(int base) => base + (_totalCharm ~/ 5);

  Character get _leftChar => _characters[0];
  Character get _rightChar => _characters[1];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _characters = _defaultCharacters
        .map((c) => Character(
              name: c.name,
              title: c.title,
              description: c.description,
              favoriteGift: c.favoriteGift,
              imageUrl: c.imageUrl,
              affection: c.affection,
              dates: c.dates,
              gifts: c.gifts,
            ))
        .toList();

    await _loadEvents();
    await _loadProgress();

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadEvents() async {
    final raw = await rootBundle.loadString('assets/story_events.json');
    final decoded = jsonDecode(raw) as List<dynamic>;
    _events = decoded.map((e) => StoryEvent.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_saveKey);
    if (raw == null) return;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _storyIndex = (data['storyIndex'] as int? ?? 0).clamp(0, _events.length - 1);
      _baseCharm = data['baseCharm'] as int? ?? 10;
      _equippedItemId = data['equippedItemId'] as String?;
      _logs
        ..clear()
        ..addAll((data['logs'] as List<dynamic>? ?? []).map((e) => e.toString()));

      final savedCharacters = (data['characters'] as List<dynamic>? ?? [])
          .map((e) => Character.fromJson(e as Map<String, dynamic>))
          .toList();

      if (savedCharacters.length == _characters.length) {
        _characters = savedCharacters;
      }
    } catch (_) {}
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'storyIndex': _storyIndex,
      'baseCharm': _baseCharm,
      'equippedItemId': _equippedItemId,
      'logs': _logs,
      'characters': _characters.map((c) => c.toJson()).toList(),
    };
    await prefs.setString(_saveKey, jsonEncode(data));
  }

  Character _findCharacter(String name) => _characters.firstWhere((c) => c.name == name);

  Future<void> _applyChoice(StoryChoice choice) async {
    final gain = _withCharmBonus(choice.affectionDelta);
    setState(() {
      final c = _findCharacter(choice.target);
      c.affection = (c.affection + gain).clamp(0, 100);
      _logs.insert(0, '[스토리] ${choice.result} (${c.name} +$gain)');
      if (_storyIndex < _events.length - 1) _storyIndex += 1;
    });
    await _saveProgress();
    _showSnack('${choice.result} (+$gain)');
  }

  Future<void> _goDate(Character character) async {
    final gain = _withCharmBonus(8);
    setState(() {
      character.dates += 1;
      character.affection = (character.affection + gain).clamp(0, 100);
      _logs.insert(0, '[데이트] ${character.name}와 데이트 (+$gain)');
    });
    await _saveProgress();
    _showSnack('${character.name}와 데이트!');
  }

  Future<void> _sendGift(Character character) async {
    final favoriteBonus = character.gifts % 2 == 0;
    final gain = _withCharmBonus(favoriteBonus ? 12 : 6);
    setState(() {
      character.gifts += 1;
      character.affection = (character.affection + gain).clamp(0, 100);
      _logs.insert(0, '[선물] ${character.name}에게 선물 (+$gain)');
    });
    await _saveProgress();
    _showSnack('${character.name}에게 선물 완료!');
  }

  Future<void> _tapCharacter(Character c) async {
    setState(() {
      c.affection = (c.affection + 1).clamp(0, 100);
      _logs.insert(0, '[상호작용] ${c.name}과 시선이 마주쳤다 (+1)');
    });
    await _saveProgress();
  }

  Future<void> _equipItem(GearItem item) async {
    setState(() {
      _equippedItemId = item.id;
      _logs.insert(0, '[장착] ${item.name} 장착 (매력 +${item.charmBonus})');
    });
    await _saveProgress();
  }

  Future<void> _unequipItem() async {
    setState(() {
      _equippedItemId = null;
      _logs.insert(0, '[장착] 아이템 해제');
    });
    await _saveProgress();
  }

  Future<void> _resetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_saveKey);
    setState(() {
      _storyIndex = 0;
      _baseCharm = 10;
      _equippedItemId = null;
      _logs.clear();
      _characters = _defaultCharacters
          .map((c) => Character(
                name: c.name,
                title: c.title,
                description: c.description,
                favoriteGift: c.favoriteGift,
                imageUrl: c.imageUrl,
                affection: c.affection,
                dates: c.dates,
                gifts: c.gifts,
              ))
          .toList();
    });
  }

  bool get _isStoryFinished => _events.isNotEmpty && _storyIndex >= _events.length - 1;

  String _endingText() {
    final sorted = [..._characters]..sort((a, b) => b.affection.compareTo(a.affection));
    final top = sorted.first;
    if (top.affection >= 80) return '엔딩: ${top.name} 해피엔딩';
    if (top.affection >= 60) return '엔딩: ${top.name} 우정+로맨스 엔딩';
    return '엔딩: 독립 엔딩';
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pages = [_buildPlayPage(), _buildRelationshipPage(), _buildEventLogPage()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('중세 비주얼노벨 MVP'),
        actions: [IconButton(onPressed: _resetProgress, icon: const Icon(Icons.refresh))],
      ),
      body: pages[_selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (value) => setState(() => _selectedTab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.videogame_asset), label: '플레이'),
          NavigationDestination(icon: Icon(Icons.people), label: '관계/장비'),
          NavigationDestination(icon: Icon(Icons.history), label: '로그'),
        ],
      ),
    );
  }

  Widget _buildPlayPage() {
    final event = _events[_storyIndex];

    return Stack(
      children: [
        Positioned.fill(
          child: event.backgroundUrl.isNotEmpty
              ? Image.network(event.backgroundUrl, fit: BoxFit.cover)
              : Container(color: const Color(0xFF2E2A3B)),
        ),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),

        Positioned(
          left: 20,
          bottom: 140,
          child: _characterSprite(_leftChar, isLeft: true),
        ),
        Positioned(
          right: 20,
          bottom: 140,
          child: _characterSprite(_rightChar, isLeft: false),
        ),

        Positioned(
          right: 16,
          top: 16,
          child: Card(
            color: Colors.black.withOpacity(0.45),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text(
                '매력 $_totalCharm  |  진행 ${_storyIndex + 1}/${_events.length}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),

        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _dialogPanel(event),
        ),
      ],
    );
  }

  Widget _characterSprite(Character c, {required bool isLeft}) {
    return GestureDetector(
      onTap: () => _tapCharacter(c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 150,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            CircleAvatar(radius: 42, backgroundImage: NetworkImage(c.imageUrl)),
            const SizedBox(height: 8),
            Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('❤ ${c.affection}', style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 10),
            const Text('탭: 호감 +1', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _dialogPanel(StoryEvent event) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.72),
        border: const Border(top: BorderSide(color: Colors.white24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${event.speaker} · ${event.title}',
              style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(event.line.isNotEmpty ? event.line : event.description, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...event.choices.map(
                  (choice) => ElevatedButton(
                    onPressed: _isStoryFinished ? null : () => _applyChoice(choice),
                    child: Text(choice.label),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _goDate(_leftChar.affection >= _rightChar.affection ? _leftChar : _rightChar),
                  child: const Text('빠른 데이트'),
                ),
                OutlinedButton(
                  onPressed: () => _sendGift(_leftChar.affection >= _rightChar.affection ? _leftChar : _rightChar),
                  child: const Text('빠른 선물'),
                ),
              ],
            ),
            if (_isStoryFinished) ...[
              const SizedBox(height: 10),
              Text(_endingText(), style: const TextStyle(color: Colors.lightGreenAccent)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRelationshipPage() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('주인공 스탯', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('기본 매력 $_baseCharm · 장착 +$_equippedCharmBonus · 총 매력 $_totalCharm'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._gearItems.map((item) => OutlinedButton(
                        onPressed: () => _equipItem(item),
                        child: Text('${item.name} (+${item.charmBonus})'),
                      )),
                  TextButton(onPressed: _unequipItem, child: const Text('해제')),
                ],
              ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        ..._characters.map((c) => Card(
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(c.imageUrl)),
                title: Text('${c.name} · ${c.title}'),
                subtitle: Text('호감 ${c.affection} | 데이트 ${c.dates} | 선물 ${c.gifts}'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(onPressed: () => _goDate(c), icon: const Icon(Icons.favorite)),
                    IconButton(onPressed: () => _sendGift(c), icon: const Icon(Icons.card_giftcard)),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildEventLogPage() {
    if (_logs.isEmpty) return const Center(child: Text('로그가 없습니다.'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) => Text(_logs[i]),
    );
  }
}
