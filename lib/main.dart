import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const StoryApp());
}

class StoryApp extends StatelessWidget {
  const StoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '로열 하트 크로니클',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF7B2E3B)),
        useMaterial3: true,
      ),
      home: const GameShell(),
    );
  }
}

class Character {
  Character({
    required this.name,
    required this.role,
    required this.portraitUrl,
    required this.description,
    this.affection = 30,
  });

  final String name;
  final String role;
  final String portraitUrl;
  final String description;
  int affection;

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'portraitUrl': portraitUrl,
        'description': description,
        'affection': affection,
      };

  factory Character.fromJson(Map<String, dynamic> json) => Character(
        name: json['name'],
        role: json['role'],
        portraitUrl: json['portraitUrl'],
        description: json['description'],
        affection: json['affection'] ?? 30,
      );
}

class StoryChoice {
  StoryChoice({
    required this.label,
    required this.mainTarget,
    required this.mainDelta,
    required this.result,
    this.sideTarget,
    this.sideDelta = 0,
  });

  final String label;
  final String mainTarget;
  final int mainDelta;
  final String result;
  final String? sideTarget;
  final int sideDelta;
}

class StoryBeat {
  StoryBeat({
    required this.title,
    required this.speaker,
    required this.line,
    required this.backgroundUrl,
    required this.choices,
  });

  final String title;
  final String speaker;
  final String line;
  final String backgroundUrl;
  final List<StoryChoice> choices;
}

class ShopItem {
  ShopItem({
    required this.id,
    required this.name,
    required this.price,
    required this.description,
    required this.affectionBoost,
  });

  final String id;
  final String name;
  final int price;
  final String description;
  final int affectionBoost;
}

class OutfitItem {
  OutfitItem({
    required this.id,
    required this.name,
    required this.price,
    required this.avatarUrl,
    required this.charmBonus,
  });

  final String id;
  final String name;
  final int price;
  final String avatarUrl;
  final int charmBonus;
}

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  static const _saveKey = 'vn_save_v4';

  final Random _random = Random();

  int _menuIndex = 0; // 0 home,1 story,2 parttime,3 shop,4 date,5 log
  int _gold = 120;
  int _storyIndex = 0;
  int _baseCharm = 12;
  bool _loaded = false;

  String _equippedOutfitId = 'default';
  final List<String> _logs = [];

  int _workTimeLeft = 0;
  int _workScore = 0;

  final List<Character> _characters = [
    Character(
      name: '엘리안',
      role: '왕실 근위대장',
      portraitUrl:
          'https://images.unsplash.com/photo-1547425260-76bcadfb4f2c?auto=format&fit=crop&w=900&q=80',
      description: '신념이 강한 기사. 위기에서 더 빛난다.',
    ),
    Character(
      name: '루시안',
      role: '궁정 마도학자',
      portraitUrl:
          'https://images.unsplash.com/photo-1542204625-de293a23b6b2?auto=format&fit=crop&w=900&q=80',
      description: '차갑지만 깊이 있는 전략가.',
    ),
    Character(
      name: '세레나',
      role: '귀족 외교관',
      portraitUrl:
          'https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?auto=format&fit=crop&w=900&q=80',
      description: '사교의 달인. 미묘한 감정선을 읽는다.',
      affection: 26,
    ),
  ];

  final List<OutfitItem> _outfits = [
    OutfitItem(
      id: 'default',
      name: '수수한 여행복',
      price: 0,
      charmBonus: 0,
      avatarUrl:
          'https://api.dicebear.com/9.x/adventurer/png?seed=HeroineDefault&backgroundColor=f3e8ff',
    ),
    OutfitItem(
      id: 'noble_dress',
      name: '귀족 연회 드레스',
      price: 220,
      charmBonus: 4,
      avatarUrl:
          'https://api.dicebear.com/9.x/adventurer/png?seed=HeroineNoble&backgroundColor=fde68a',
    ),
    OutfitItem(
      id: 'ranger_look',
      name: '숲의 레인저 복장',
      price: 180,
      charmBonus: 3,
      avatarUrl:
          'https://api.dicebear.com/9.x/adventurer/png?seed=HeroineRanger&backgroundColor=bbf7d0',
    ),
    OutfitItem(
      id: 'moon_gown',
      name: '월광 궁정 예복',
      price: 380,
      charmBonus: 7,
      avatarUrl:
          'https://api.dicebear.com/9.x/adventurer/png?seed=HeroineMoon&backgroundColor=c4b5fd',
    ),
  ];

  final List<ShopItem> _giftItems = [
    ShopItem(id: 'rose_box', name: '왕실 장미 상자', price: 60, description: '부드러운 향으로 분위기를 살린다.', affectionBoost: 5),
    ShopItem(id: 'silver_ring', name: '은세공 반지', price: 110, description: '진심을 담아 전달되는 선물.', affectionBoost: 9),
    ShopItem(id: 'ancient_book', name: '고대 문양 서책', price: 140, description: '지적 호감도를 크게 자극.', affectionBoost: 11),
  ];

  late final List<StoryBeat> _story = [
    StoryBeat(
      title: '왕궁 입성',
      speaker: '나레이션',
      line: '세력 균형이 무너지는 왕궁. 당신의 선택이 모두의 운명을 바꾼다.',
      backgroundUrl:
          'https://images.unsplash.com/photo-1518002054494-3a6f94352e9d?auto=format&fit=crop&w=1600&q=80',
      choices: [
        StoryChoice(
          label: '엘리안과 경비 계획을 점검한다',
          mainTarget: '엘리안',
          mainDelta: 10,
          sideTarget: '루시안',
          sideDelta: -1,
          result: '엘리안은 신뢰를 보냈지만 루시안은 계산을 다시 시작했다.',
        ),
        StoryChoice(
          label: '루시안과 첩보 보고서를 분석한다',
          mainTarget: '루시안',
          mainDelta: 10,
          sideTarget: '세레나',
          sideDelta: 1,
          result: '루시안은 미소를 감추고, 세레나는 흥미를 드러냈다.',
        ),
      ],
    ),
    StoryBeat(
      title: '가면무도회',
      speaker: '세레나',
      line: '누구와 춤을 출지에 따라 동맹의 방향이 달라질 거예요.',
      backgroundUrl:
          'https://images.unsplash.com/photo-1522673607200-164d1b6ce486?auto=format&fit=crop&w=1600&q=80',
      choices: [
        StoryChoice(
          label: '세레나와 정치적 연합을 맺는다',
          mainTarget: '세레나',
          mainDelta: 11,
          sideTarget: '엘리안',
          sideDelta: -1,
          result: '세레나는 당신에게 깊은 신뢰를 보냈다.',
        ),
        StoryChoice(
          label: '엘리안과 춤을 추며 민심을 다독인다',
          mainTarget: '엘리안',
          mainDelta: 9,
          sideTarget: '세레나',
          sideDelta: 1,
          result: '엘리안은 굳은 눈빛 속에서 따뜻함을 보였다.',
        ),
      ],
    ),
    StoryBeat(
      title: '마탑의 밤',
      speaker: '루시안',
      line: '지금 이 결계를 선택하면, 누군가는 당신 편이 되고 누군가는 멀어집니다.',
      backgroundUrl:
          'https://images.unsplash.com/photo-1518562180175-34a163b1a9a6?auto=format&fit=crop&w=1600&q=80',
      choices: [
        StoryChoice(
          label: '루시안의 실험을 허가한다',
          mainTarget: '루시안',
          mainDelta: 12,
          sideTarget: '엘리안',
          sideDelta: -2,
          result: '루시안은 처음으로 감정을 숨기지 못했다.',
        ),
        StoryChoice(
          label: '실험 중지, 시민 안전을 우선한다',
          mainTarget: '엘리안',
          mainDelta: 9,
          sideTarget: '루시안',
          sideDelta: -2,
          result: '엘리안은 고개를 끄덕였지만 루시안은 침묵했다.',
        ),
      ],
    ),
  ];

  int get _equippedCharm => _outfits.firstWhere((e) => e.id == _equippedOutfitId).charmBonus;
  String get _playerAvatar => _outfits.firstWhere((e) => e.id == _equippedOutfitId).avatarUrl;
  int get _totalCharm => _baseCharm + _equippedCharm;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final pref = await SharedPreferences.getInstance();
    final raw = pref.getString(_saveKey);
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _gold = m['gold'] ?? _gold;
      _storyIndex = m['storyIndex'] ?? _storyIndex;
      _baseCharm = m['baseCharm'] ?? _baseCharm;
      _equippedOutfitId = m['equippedOutfitId'] ?? _equippedOutfitId;
      _logs
        ..clear()
        ..addAll((m['logs'] as List<dynamic>? ?? []).map((e) => e.toString()));
      final charRaw = (m['characters'] as List<dynamic>? ?? []);
      if (charRaw.length == _characters.length) {
        for (int i = 0; i < _characters.length; i++) {
          _characters[i].affection = (charRaw[i]['affection'] ?? _characters[i].affection) as int;
        }
      }
    }
    if (mounted) {
      setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    final pref = await SharedPreferences.getInstance();
    await pref.setString(
      _saveKey,
      jsonEncode({
        'gold': _gold,
        'storyIndex': _storyIndex,
        'baseCharm': _baseCharm,
        'equippedOutfitId': _equippedOutfitId,
        'logs': _logs,
        'characters': _characters.map((e) => e.toJson()).toList(),
      }),
    );
  }

  Character _c(String name) => _characters.firstWhere((e) => e.name == name);

  int _scaledGain(int base) => base + (_totalCharm ~/ 5);

  Future<void> _pickStoryChoice(StoryChoice choice) async {
    final main = _c(choice.mainTarget);
    final gain = _scaledGain(choice.mainDelta);
    main.affection = (main.affection + gain).clamp(0, 100);

    if (choice.sideTarget != null) {
      final side = _c(choice.sideTarget!);
      side.affection = (side.affection + choice.sideDelta).clamp(0, 100);
    }

    if (_storyIndex < _story.length - 1) _storyIndex += 1;

    _logs.insert(0, '[스토리] ${choice.result}');
    await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(choice.result)));
      setState(() {});
    }
  }

  Future<void> _buyGift(ShopItem item, Character target) async {
    if (_gold < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('골드가 부족합니다.')));
      return;
    }
    _gold -= item.price;
    final gain = _scaledGain(item.affectionBoost);
    target.affection = (target.affection + gain).clamp(0, 100);
    _logs.insert(0, '[상점] ${item.name} 구매 -> ${target.name} 호감 +$gain');
    await _save();
    setState(() {});
  }

  Future<void> _buyOutfit(OutfitItem item) async {
    if (_gold < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('골드가 부족합니다.')));
      return;
    }
    _gold -= item.price;
    _equippedOutfitId = item.id;
    _logs.insert(0, '[장착] ${item.name} 착용 (매력 +${item.charmBonus})');
    await _save();
    setState(() {});
  }

  Future<void> _startWorkMiniGame() async {
    _workTimeLeft = 10;
    _workScore = 0;
    setState(() {});

    while (_workTimeLeft > 0) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _menuIndex != 2) break;
      _workTimeLeft -= 1;
      setState(() {});
    }

    if (!mounted) return;
    final reward = 20 + (_workScore * 7);
    _gold += reward;
    _logs.insert(0, '[아르바이트] 점수 $_workScore점, 골드 +$reward');
    await _save();
    if (_menuIndex == 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('아르바이트 완료! +$reward G')));
      setState(() {});
    }
  }

  Future<void> _dateRandom(Character target) async {
    final affection = target.affection;
    final events = <String>[
      if (affection < 40) '${target.name}와 어색한 산책. 아직 서로를 탐색하는 단계다.',
      if (affection >= 40 && affection < 70) '${target.name}와 비밀 정원에서 웃음이 이어졌다.',
      if (affection >= 70) '${target.name}와 달빛 아래 진심을 고백하는 순간이 찾아왔다.',
      '${target.name}와 시장 데이트 중 소소한 선물을 주고받았다.',
      '${target.name}와 마차 여행에서 예상치 못한 사건을 함께 해결했다.',
    ];

    final picked = events[_random.nextInt(events.length)];
    final gain = _scaledGain(6 + _random.nextInt(6));
    target.affection = (target.affection + gain).clamp(0, 100);
    _logs.insert(0, '[데이트] $picked (+$gain)');
    await _save();
    if (mounted) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('${target.name} 데이트 이벤트'),
          content: Text('$picked\n\n호감도 +$gain'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
        ),
      );
      setState(() {});
    }
  }

  Widget _statChip(String label, String value) {
    return Chip(
      label: Text('$label $value'),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('로열 하트 크로니클'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('💰 $_gold')),
          )
        ],
      ),
      body: IndexedStack(
        index: _menuIndex,
        children: [
          _homePage(),
          _storyPage(),
          _workPage(),
          _shopPage(),
          _datePage(),
          _logPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _menuIndex,
        onDestinationSelected: (v) => setState(() => _menuIndex = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.auto_stories), label: '스토리'),
          NavigationDestination(icon: Icon(Icons.construction), label: '아르바이트'),
          NavigationDestination(icon: Icon(Icons.store), label: '상점'),
          NavigationDestination(icon: Icon(Icons.favorite), label: '데이트'),
          NavigationDestination(icon: Icon(Icons.history), label: '로그'),
        ],
      ),
    );
  }

  Widget _homePage() {
    final outfit = _outfits.firstWhere((e) => e.id == _equippedOutfitId);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          height: 220,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            image: const DecorationImage(
              image: NetworkImage(
                'https://images.unsplash.com/photo-1447069387593-a5de0862481e?auto=format&fit=crop&w=1600&q=80',
              ),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.black.withOpacity(0.32),
            ),
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(radius: 46, backgroundImage: NetworkImage(_playerAvatar)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('주인공 상태', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('착용: ${outfit.name}', style: const TextStyle(color: Colors.white70)),
                      Text('총 매력: $_totalCharm (기본 $_baseCharm + 장착 $_equippedCharm)', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _menuCard('스토리', Icons.auto_stories, Colors.purple, () => setState(() => _menuIndex = 1)),
            _menuCard('아르바이트', Icons.construction, Colors.blue, () => setState(() => _menuIndex = 2)),
            _menuCard('상점', Icons.store, Colors.orange, () => setState(() => _menuIndex = 3)),
            _menuCard('데이트', Icons.favorite, Colors.pink, () => setState(() => _menuIndex = 4)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _statChip('💰', '$_gold'),
            _statChip('⭐', '스토리 ${_storyIndex + 1}/${_story.length}'),
            ..._characters.map((c) => _statChip(c.name, '${c.affection}')),
          ],
        )
      ],
    );
  }

  Widget _menuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: [color.withOpacity(0.8), color.withOpacity(0.5)]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: Colors.white),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _storyPage() {
    final beat = _story[_storyIndex];

    return Stack(
      children: [
        Positioned.fill(child: Image.network(beat.backgroundUrl, fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.28))),
        Positioned(left: 16, bottom: 170, child: _characterPanel(_characters[0])),
        Positioned(right: 16, bottom: 170, child: _characterPanel(_characters[1])),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            color: Colors.black.withOpacity(0.74),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${beat.speaker} · ${beat.title}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(beat.line, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: beat.choices
                        .map((e) => ElevatedButton(onPressed: () => _pickStoryChoice(e), child: Text(e.label)))
                        .toList(),
                  )
                ],
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _characterPanel(Character c) {
    return GestureDetector(
      onTap: () async {
        c.affection = (c.affection + 1).clamp(0, 100);
        _logs.insert(0, '[상호작용] ${c.name}과 눈이 마주쳤다 (+1)');
        await _save();
        setState(() {});
      },
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          children: [
            CircleAvatar(radius: 34, backgroundImage: NetworkImage(c.portraitUrl)),
            const SizedBox(height: 6),
            Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            Text('❤ ${c.affection}', style: const TextStyle(color: Colors.white70)),
          ],
        ),
      ),
    );
  }

  Widget _workPage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('아르바이트 미니게임', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('10초 동안 버튼을 최대한 많이 클릭해서 재화를 획득하세요.'),
            const SizedBox(height: 14),
            Text('남은 시간: $_workTimeLeft초'),
            Text('점수: $_workScore'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _workTimeLeft > 0
                  ? () {
                      setState(() => _workScore += 1);
                    }
                  : null,
              child: const Text('작업! (+1점)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _workTimeLeft > 0 ? null : _startWorkMiniGame,
              child: const Text('아르바이트 시작'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shopPage() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('의상 상점 (착용 시 외형/매력 변화)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._outfits.map((o) => Card(
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(o.avatarUrl)),
                title: Text('${o.name}  (+${o.charmBonus} 매력)'),
                subtitle: Text(o.price == 0 ? '기본 의상' : '${o.price} G'),
                trailing: FilledButton(
                  onPressed: o.id == _equippedOutfitId
                      ? null
                      : () {
                          if (o.price == 0) {
                            setState(() => _equippedOutfitId = o.id);
                            _save();
                          } else {
                            _buyOutfit(o);
                          }
                        },
                  child: Text(o.id == _equippedOutfitId ? '착용중' : '착용'),
                ),
              ),
            )),
        const SizedBox(height: 10),
        const Text('호감도 아이템', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._giftItems.map((item) => Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item.name} · ${item.price}G', style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(item.description),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _characters
                          .map((c) => OutlinedButton(
                                onPressed: () => _buyGift(item, c),
                                child: Text('${c.name}에게 선물'),
                              ))
                          .toList(),
                    )
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _datePage() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('데이트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('호감도에 따라 랜덤 이벤트가 달라집니다.'),
        const SizedBox(height: 8),
        ..._characters.map((c) => Card(
              child: ListTile(
                leading: CircleAvatar(backgroundImage: NetworkImage(c.portraitUrl)),
                title: Text('${c.name} (${c.role})'),
                subtitle: Text('호감도 ${c.affection}'),
                trailing: FilledButton(
                  onPressed: () => _dateRandom(c),
                  child: const Text('데이트'),
                ),
              ),
            )),
      ],
    );
  }

  Widget _logPage() {
    if (_logs.isEmpty) return const Center(child: Text('아직 기록이 없습니다.'));
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemBuilder: (_, i) => Text(_logs[i]),
      separatorBuilder: (_, __) => const Divider(),
      itemCount: _logs.length,
    );
  }
}
