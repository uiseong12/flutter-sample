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
  });

  final String title;
  final String description;
  final List<StoryChoice> choices;

  factory StoryEvent.fromJson(Map<String, dynamic> json) {
    final choices = (json['choices'] as List<dynamic>)
        .map((e) => StoryChoice.fromJson(e as Map<String, dynamic>))
        .toList();

    return StoryEvent(
      title: json['title'] as String,
      description: json['description'] as String,
      choices: choices,
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
  static const _saveKey = 'story_save_v2';

  int _selectedTab = 0;
  int _storyIndex = 0;
  bool _isLoading = true;

  final List<String> _logs = [];

  int _baseCharm = 10;
  String? _equippedItemId;

  final List<GearItem> _gearItems = [
    GearItem(
      id: 'silver_tiara',
      name: '은빛 티아라',
      description: '품위를 더해 첫인상을 높여준다.',
      charmBonus: 4,
    ),
    GearItem(
      id: 'rose_perfume',
      name: '장미 향수',
      description: '가까운 대화에서 매력이 돋보인다.',
      charmBonus: 6,
    ),
    GearItem(
      id: 'moon_necklace',
      name: '월광 목걸이',
      description: '신비로운 분위기로 호감 상승 효과 강화.',
      charmBonus: 8,
    ),
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

  int _withCharmBonus(int base) {
    // 매력 5당 +1 보정
    final charmScaled = _totalCharm ~/ 5;
    return base + charmScaled;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _characters = _defaultCharacters
        .map(
          (c) => Character(
            name: c.name,
            title: c.title,
            description: c.description,
            favoriteGift: c.favoriteGift,
            imageUrl: c.imageUrl,
            affection: c.affection,
            dates: c.dates,
            gifts: c.gifts,
          ),
        )
        .toList();

    await _loadEvents();
    await _loadProgress();

    if (mounted) {
      setState(() => _isLoading = false);
    }
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
        _characters = savedCharacters
            .map((s) {
              if (s.imageUrl.isNotEmpty) return s;
              final fallback = _defaultCharacters.firstWhere((d) => d.name == s.name);
              return Character(
                name: s.name,
                title: s.title,
                description: s.description,
                favoriteGift: s.favoriteGift,
                imageUrl: fallback.imageUrl,
                affection: s.affection,
                dates: s.dates,
                gifts: s.gifts,
              );
            })
            .toList();
      }
    } catch (_) {
      // ignore broken save data
    }
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

  Character _findCharacter(String name) {
    return _characters.firstWhere((c) => c.name == name);
  }

  Future<void> _applyChoice(StoryChoice choice) async {
    final gain = _withCharmBonus(choice.affectionDelta);

    setState(() {
      final character = _findCharacter(choice.target);
      character.affection = (character.affection + gain).clamp(0, 100);
      _logs.insert(0, '[스토리] ${choice.result} (${character.name} +$gain)');
      if (_storyIndex < _events.length - 1) {
        _storyIndex += 1;
      }
    });

    await _saveProgress();
    _showSnack('${choice.result} (매력 보정 적용 +$gain)');
  }

  Future<void> _goDate(Character character) async {
    const base = 8;
    final gain = _withCharmBonus(base);

    setState(() {
      character.dates += 1;
      character.affection = (character.affection + gain).clamp(0, 100);
      _logs.insert(0, '[데이트] ${character.name}와 분수대 산책 (+$gain)');
    });

    await _saveProgress();
    _showSnack('${character.name}와 데이트를 즐겼어요. (+$gain)');
  }

  Future<void> _sendGift(Character character) async {
    final bool favoriteBonus = character.gifts % 2 == 0;
    final int base = favoriteBonus ? 12 : 6;
    final gain = _withCharmBonus(base);

    setState(() {
      character.gifts += 1;
      character.affection = (character.affection + gain).clamp(0, 100);
      _logs.insert(
        0,
        '[선물] ${character.name}에게 ${favoriteBonus ? character.favoriteGift : '향초'} 전달 (+$gain)',
      );
    });

    await _saveProgress();
    _showSnack('${character.name}에게 선물을 전했어요. (+$gain)');
  }

  Future<void> _equipItem(GearItem item) async {
    setState(() {
      _equippedItemId = item.id;
      _logs.insert(0, '[장착] ${item.name} 장착 (매력 +${item.charmBonus})');
    });
    await _saveProgress();
    _showSnack('${item.name} 장착! 총 매력 $_totalCharm');
  }

  Future<void> _unequipItem() async {
    setState(() {
      _equippedItemId = null;
      _logs.insert(0, '[장착] 아이템 해제');
    });
    await _saveProgress();
    _showSnack('아이템을 해제했어요.');
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
          .map(
            (c) => Character(
              name: c.name,
              title: c.title,
              description: c.description,
              favoriteGift: c.favoriteGift,
              imageUrl: c.imageUrl,
              affection: c.affection,
              dates: c.dates,
              gifts: c.gifts,
            ),
          )
          .toList();
    });

    _showSnack('진행 상황을 초기화했어요.');
  }

  String _endingText() {
    final sorted = [..._characters]..sort((a, b) => b.affection.compareTo(a.affection));
    final top = sorted.first;

    if (top.affection >= 80) {
      return '엔딩: ${top.name}와 함께 왕국의 새 시대를 여는 해피엔딩';
    }
    if (top.affection >= 60) {
      return '엔딩: ${top.name}와 서로를 이해하며 천천히 가까워지는 엔딩';
    }
    return '엔딩: 사랑보다 사명을 택한 독립 엔딩';
  }

  bool get _isStoryFinished => _events.isNotEmpty && _storyIndex >= _events.length - 1;

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      _buildStoryPage(),
      _buildCharactersPage(),
      _buildEventLogPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('중세 여주 로맨스 MVP+'),
        actions: [
          IconButton(
            onPressed: _resetProgress,
            tooltip: '리셋',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: pages[_selectedTab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (value) => setState(() => _selectedTab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.menu_book), label: '스토리'),
          NavigationDestination(icon: Icon(Icons.people), label: '관계'),
          NavigationDestination(icon: Icon(Icons.history), label: '이벤트'),
        ],
      ),
    );
  }

  Widget _buildHeroStatusCard() {
    final equipped = _gearItems.where((i) => i.id == _equippedItemId).toList();
    final equippedName = equipped.isEmpty ? '없음' : equipped.first.name;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('주인공 상태', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('기본 매력: $_baseCharm · 장착 보너스: +$_equippedCharmBonus · 총 매력: $_totalCharm'),
            Text('장착 아이템: $equippedName'),
            const SizedBox(height: 6),
            Text('효과: 호감도 상승량에 매력 기반 보정이 추가됩니다.'),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryPage() {
    final event = _events[_storyIndex];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroStatusCard(),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(event.description),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...event.choices.map(
          (choice) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: FilledButton(
              onPressed: _isStoryFinished ? null : () => _applyChoice(choice),
              child: Text(choice.label),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '진행도: ${_storyIndex + 1} / ${_events.length}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (_isStoryFinished) ...[
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _endingText(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCharactersPage() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildHeroStatusCard(),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('장비 인벤토리', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._gearItems.map(
                      (item) => OutlinedButton(
                        onPressed: () => _equipItem(item),
                        child: Text('${item.name} (+${item.charmBonus})'),
                      ),
                    ),
                    TextButton(onPressed: _unequipItem, child: const Text('해제')),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        ..._characters.map((c) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                        backgroundImage: c.imageUrl.isNotEmpty ? NetworkImage(c.imageUrl) : null,
                        child: c.imageUrl.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${c.name} · ${c.title}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(c.description),
                  const SizedBox(height: 10),
                  LinearProgressIndicator(value: c.affection / 100),
                  const SizedBox(height: 4),
                  Text('호감도 ${c.affection} / 100 · 데이트 ${c.dates}회 · 선물 ${c.gifts}회'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _goDate(c),
                        icon: const Icon(Icons.favorite),
                        label: const Text('데이트'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _sendGift(c),
                        icon: const Icon(Icons.card_giftcard),
                        label: const Text('선물하기'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEventLogPage() {
    if (_logs.isEmpty) {
      return const Center(
        child: Text('아직 이벤트가 없어요. 스토리/데이트/선물을 진행해보세요.'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) => Text(_logs[i]),
    );
  }
}
