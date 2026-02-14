import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6D2A45)),
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
    required this.fullBodyAsset,
    required this.description,
    this.affection = 30,
  });

  final String name;
  final String role;
  final String fullBodyAsset;
  final String description;
  int affection;

  Map<String, dynamic> toJson() => {
        'name': name,
        'role': role,
        'fullBodyAsset': fullBodyAsset,
        'description': description,
        'affection': affection,
      };
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
    required this.backgroundAsset,
    required this.leftCharacter,
    required this.rightCharacter,
    required this.choices,
    this.showLeft = true,
    this.showRight = true,
  });

  final String title;
  final String speaker;
  final String line;
  final String backgroundAsset;
  final String leftCharacter;
  final String rightCharacter;
  final List<StoryChoice> choices;
  final bool showLeft;
  final bool showRight;
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
    required this.avatarAsset,
    required this.charmBonus,
  });

  final String id;
  final String name;
  final int price;
  final String avatarAsset;
  final int charmBonus;
}

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  static const _saveKey = 'vn_save_v6';
  final Random _random = Random();

  int _menuIndex = 0;
  int _gold = 120;
  int _storyIndex = 0;
  int _baseCharm = 12;
  bool _loaded = false;
  bool _inStoryScene = false;

  int _workTimeLeft = 0;
  int _workScore = 0;

  String _equippedOutfitId = 'default';
  String? _endingCharacterName;
  final List<String> _logs = [];

  final List<Character> _characters = [
    Character(
      name: '엘리안',
      role: '왕실 근위대장',
      fullBodyAsset: 'assets/art/char_elian.svg',
      description: '엄격하지만 당신 앞에서는 무너지는 기사.',
    ),
    Character(
      name: '루시안',
      role: '궁정 마도학자',
      fullBodyAsset: 'assets/art/char_lucian.svg',
      description: '이성과 감정 사이에서 흔들리는 전략가.',
    ),
    Character(
      name: '세레나',
      role: '귀족 외교관',
      fullBodyAsset: 'assets/art/char_serena.svg',
      description: '우아한 미소 뒤에 칼날을 숨긴 외교가.',
      affection: 26,
    ),
  ];

  final List<OutfitItem> _outfits = [
    OutfitItem(id: 'default', name: '수수한 여행복', price: 0, charmBonus: 0, avatarAsset: 'assets/art/player_default.svg'),
    OutfitItem(id: 'noble_dress', name: '귀족 연회 드레스', price: 220, charmBonus: 4, avatarAsset: 'assets/art/player_noble.svg'),
    OutfitItem(id: 'ranger_look', name: '숲의 레인저 복장', price: 180, charmBonus: 3, avatarAsset: 'assets/art/player_ranger.svg'),
    OutfitItem(id: 'moon_gown', name: '월광 궁정 예복', price: 380, charmBonus: 7, avatarAsset: 'assets/art/player_moon.svg'),
  ];

  final List<ShopItem> _giftItems = [
    ShopItem(id: 'rose_box', name: '왕실 장미 상자', price: 60, description: '부드러운 향으로 분위기를 바꾼다.', affectionBoost: 5),
    ShopItem(id: 'silver_ring', name: '은세공 반지', price: 110, description: '진심이 담긴 고급 선물.', affectionBoost: 9),
    ShopItem(id: 'ancient_book', name: '고대 문양 서책', price: 140, description: '지적 자극을 주는 특별한 책.', affectionBoost: 11),
  ];

  late final List<StoryBeat> _story = [
    StoryBeat(
      title: '왕궁 입성',
      speaker: '나레이션',
      line: '붉은 노을이 성벽을 물들였다. 첫 선택이 권력과 사랑의 균형을 만든다.',
      backgroundAsset: 'assets/art/story_castle.svg',
      leftCharacter: '엘리안',
      rightCharacter: '루시안',
      showLeft: false,
      showRight: false,
      choices: [
        StoryChoice(label: '[엘리안] 경비 계획을 함께 검토한다', mainTarget: '엘리안', mainDelta: 10, sideTarget: '루시안', sideDelta: -1, result: '엘리안은 당신을 신뢰하기 시작했다.'),
        StoryChoice(label: '[루시안] 첩보 보고서를 심야 분석한다', mainTarget: '루시안', mainDelta: 10, sideTarget: '세레나', sideDelta: 1, result: '루시안은 조용히 당신 편에 서기로 결심했다.'),
      ],
    ),
    StoryBeat(
      title: '가면무도회',
      speaker: '세레나',
      line: '당신이 누구와 춤을 추는지, 그 장면은 곧 정치적 선언이 된다.',
      backgroundAsset: 'assets/art/story_ballroom.svg',
      leftCharacter: '세레나',
      rightCharacter: '엘리안',
      showLeft: true,
      showRight: true,
      choices: [
        StoryChoice(label: '[세레나] 외교 연합을 제안한다', mainTarget: '세레나', mainDelta: 11, sideTarget: '엘리안', sideDelta: -1, result: '세레나는 당신에게만 비밀을 공유했다.'),
        StoryChoice(label: '[엘리안] 시민 앞에서 함께 춤춘다', mainTarget: '엘리안', mainDelta: 9, sideTarget: '세레나', sideDelta: 1, result: '엘리안의 눈빛이 흔들렸다. 더 이상 상관과 부하가 아니었다.'),
      ],
    ),
    StoryBeat(
      title: '마탑의 밤',
      speaker: '루시안',
      line: '금지된 결계는 누군가의 미래를 살리고, 또 누군가의 신념을 부순다.',
      backgroundAsset: 'assets/art/story_tower.svg',
      leftCharacter: '루시안',
      rightCharacter: '세레나',
      showLeft: true,
      showRight: false,
      choices: [
        StoryChoice(label: '[루시안] 실험을 허가하고 끝까지 함께한다', mainTarget: '루시안', mainDelta: 12, sideTarget: '엘리안', sideDelta: -2, result: '루시안은 처음으로 당신 앞에서 감정을 숨기지 않았다.'),
        StoryChoice(label: '[세레나] 시민 안전을 우선해 실험을 중지시킨다', mainTarget: '세레나', mainDelta: 10, sideTarget: '루시안', sideDelta: -2, result: '세레나는 당신의 결단에 진심 어린 존경을 보냈다.'),
      ],
    ),
    StoryBeat(
      title: '결전 전야',
      speaker: '나레이션',
      line: '전쟁의 북소리가 다가온다. 마지막 밤, 누구의 손을 잡을 것인가.',
      backgroundAsset: 'assets/art/story_castle.svg',
      leftCharacter: '엘리안',
      rightCharacter: '루시안',
      showLeft: true,
      showRight: true,
      choices: [
        StoryChoice(label: '[엘리안] 성벽 순찰을 함께하며 마음을 고백한다', mainTarget: '엘리안', mainDelta: 14, sideTarget: '루시안', sideDelta: -2, result: '엘리안은 당신의 손을 놓지 않았다.'),
        StoryChoice(label: '[루시안] 마탑 옥상에서 새벽까지 대화한다', mainTarget: '루시안', mainDelta: 14, sideTarget: '세레나', sideDelta: -1, result: '루시안은 당신에게만 약점을 보였다.'),
      ],
    ),
  ];

  late List<int?> _storySelections;

  Character _characterByName(String name) => _characters.firstWhere((e) => e.name == name);

  int get _equippedCharm => _outfits.firstWhere((e) => e.id == _equippedOutfitId).charmBonus;
  String get _playerAvatar => _outfits.firstWhere((e) => e.id == _equippedOutfitId).avatarAsset;
  int get _totalCharm => _baseCharm + _equippedCharm;

  @override
  void initState() {
    super.initState();
    _storySelections = List<int?>.filled(_story.length, null);
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
      _endingCharacterName = m['endingCharacterName'] as String?;
      _storySelections = ((m['storySelections'] as List<dynamic>?) ?? List.filled(_story.length, null))
          .map<int?>((e) => e == null ? null : e as int)
          .toList();
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
      setState(() {
        _menuIndex = 0;
        _loaded = true;
      });
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
        'endingCharacterName': _endingCharacterName,
        'storySelections': _storySelections,
        'logs': _logs,
        'characters': _characters.map((e) => e.toJson()).toList(),
      }),
    );
  }

  int _scaledGain(int base) => base + (_totalCharm ~/ 5);

  Future<void> _checkEndingIfNeeded(Character c) async {
    if (_endingCharacterName != null || c.affection < 100) return;
    _endingCharacterName = c.name;
    _logs.insert(0, '[엔딩] ${c.name} 루트 확정 (최초 100 달성)');
    await _save();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('엔딩 확정'),
        content: Text('${c.name}의 호감도가 가장 먼저 100에 도달했습니다.\n\n${c.name} 엔딩 루트가 확정됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          )
        ],
      ),
    );
  }

  Future<void> _addAffection(Character target, int delta, String logPrefix) async {
    target.affection = (target.affection + delta).clamp(0, 100);
    _logs.insert(0, '$logPrefix ${target.name} +$delta');
    await _checkEndingIfNeeded(target);
  }

  Future<void> _pickStoryChoice(StoryChoice choice, int choiceIndex) async {
    if (_endingCharacterName != null) return;

    _storySelections[_storyIndex] = choiceIndex;

    final main = _characterByName(choice.mainTarget);
    await _addAffection(main, _scaledGain(choice.mainDelta), '[스토리]');

    if (choice.sideTarget != null) {
      final side = _characterByName(choice.sideTarget!);
      side.affection = (side.affection + choice.sideDelta).clamp(0, 100);
    }

    _logs.insert(0, '[대사] ${choice.result}');
    if (_storyIndex < _story.length - 1) _storyIndex += 1;
    await _save();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(choice.result)));
    setState(() {});
  }

  Future<void> _buyGift(ShopItem item, Character target) async {
    if (_gold < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('골드가 부족합니다.')));
      return;
    }
    _gold -= item.price;
    await _addAffection(target, _scaledGain(item.affectionBoost), '[상점] ${item.name} 선물 ->');
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
      if (affection < 40) '${target.name}와 서먹한 산책. 대화는 짧았지만 눈빛은 오래 남았다.',
      if (affection >= 40 && affection < 70) '${target.name}와 분수대 벤치에서 깊은 대화를 나눴다.',
      if (affection >= 70) '${target.name}와 달빛 아래 진심을 고백하는 순간이 찾아왔다.',
      '${target.name}와 시장 데이트 중 소소한 선물을 주고받았다.',
      '${target.name}와 마차 여행에서 예상치 못한 사건을 함께 해결했다.',
    ];

    final picked = events[_random.nextInt(events.length)];
    final gain = _scaledGain(6 + _random.nextInt(6));
    await _addAffection(target, gain, '[데이트]');
    _logs.insert(0, '[상황] $picked');
    await _save();

    if (!mounted) return;
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

  Widget _fullBodySprite(String asset, {double width = 220}) {
    return SizedBox(width: width, height: width * 1.45, child: SvgPicture.asset(asset, fit: BoxFit.contain));
  }

  Widget _statChip(String label, String value) => Chip(label: Text('$label $value'), visualDensity: VisualDensity.compact);

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text('로열 하트 크로니클'),
        actions: [
          if (_endingCharacterName != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text('엔딩: $_endingCharacterName', style: const TextStyle(fontWeight: FontWeight.bold))),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('💰 $_gold')),
          ),
        ],
      ),
      body: IndexedStack(
        index: _menuIndex,
        children: [_homePage(), _storyRootPage(), _workPage(), _shopPage(), _datePage(), _logPage()],
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
          height: 280,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(child: SvgPicture.asset('assets/art/home_bg.svg', fit: BoxFit.cover)),
                Positioned.fill(child: Container(color: Colors.black.withOpacity(0.28))),
                Positioned(left: 12, bottom: 0, child: _fullBodySprite(_playerAvatar, width: 180)),
                Positioned(
                  right: 14,
                  top: 20,
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('주인공 상태', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 6),
                        Text('착용: ${outfit.name}', style: const TextStyle(color: Colors.white70)),
                        Text('총 매력: $_totalCharm', style: const TextStyle(color: Colors.white70)),
                        const Text('엔딩 조건: 호감도 100 선점', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  ),
                )
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
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _statChip('💰', '$_gold'),
            _statChip('⭐', '진행 ${_storySelections.where((e) => e != null).length}/${_story.length}'),
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
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: LinearGradient(colors: [color.withOpacity(0.85), color.withOpacity(0.5)])),
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

  Widget _storyRootPage() {
    return _inStoryScene ? _storyScenePage() : _storyProgressPage();
  }

  Widget _storyProgressPage() {
    final cleared = _storySelections.where((e) => e != null).length;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('스토리 진행도', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 8),
                _progressRouteLine(),
                const SizedBox(height: 6),
                Text('클리어: $cleared / ${_story.length}'),
                if (_endingCharacterName != null)
                  Text('확정 엔딩: $_endingCharacterName', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => setState(() => _inStoryScene = true),
                  child: Text(cleared == 0 ? '스토리 시작' : '스토리 이어하기'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...List.generate(_story.length, (i) {
          final beat = _story[i];
          final picked = _storySelections[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('EP ${i + 1}. ${beat.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(beat.line, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  if (picked == null)
                    const Text('선택 전', style: TextStyle(color: Colors.grey))
                  else
                    Text('선택 루트: ${beat.choices[picked].label}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );
        })
      ],
    );
  }

  Widget _progressRouteLine() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_story.length, (i) {
          final done = _storySelections[i] != null;
          return Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? Colors.pink : Colors.white,
                  border: Border.all(color: Colors.pink),
                  shape: BoxShape.circle,
                ),
                child: Text(done ? '●' : '○', style: TextStyle(color: done ? Colors.white : Colors.pink, fontSize: 12)),
              ),
              if (i != _story.length - 1)
                Container(
                  width: 26,
                  height: 2,
                  color: (_storySelections[i] != null) ? Colors.pink : Colors.grey.shade400,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _storyScenePage() {
    final beat = _story[_storyIndex];
    final left = _characterByName(beat.leftCharacter);
    final right = _characterByName(beat.rightCharacter);

    return Stack(
      children: [
        Positioned.fill(child: SvgPicture.asset(beat.backgroundAsset, fit: BoxFit.cover)),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.32))),
        Positioned(
          top: 10,
          left: 10,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.4), foregroundColor: Colors.white),
            onPressed: () => setState(() => _inStoryScene = false),
            icon: const Icon(Icons.arrow_back),
            label: const Text('스토리 맵'),
          ),
        ),
        Positioned(left: 8, bottom: 130, child: _animatedCharacterCard(left, visible: beat.showLeft)),
        Positioned(right: 8, bottom: 130, child: _animatedCharacterCard(right, visible: beat.showRight)),
        Positioned(left: 0, right: 0, bottom: 0, child: _dialogWindow(beat)),
      ],
    );
  }

  Widget _animatedCharacterCard(Character c, {required bool visible}) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 350),
      offset: visible ? Offset.zero : const Offset(0, 0.12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 280),
        opacity: visible ? 1 : 0,
        child: GestureDetector(
          onTap: () async {
            if (!visible || _endingCharacterName != null) return;
            await _addAffection(c, 1, '[상호작용]');
            await _save();
            if (mounted) setState(() {});
          },
          child: Container(
            width: 210,
            height: 330,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.36),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Expanded(child: _fullBodySprite(c.fullBodyAsset, width: 170)),
                Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text('❤ ${c.affection}', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogWindow(StoryBeat beat) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      color: Colors.black.withOpacity(0.78),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${beat.speaker} · ${beat.title}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(beat.line, style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(
                beat.choices.length,
                (i) => ElevatedButton(
                  onPressed: _endingCharacterName != null ? null : () => _pickStoryChoice(beat.choices[i], i),
                  child: Text(beat.choices[i].label),
                ),
              ),
            ),
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
            FilledButton(onPressed: _workTimeLeft > 0 ? () => setState(() => _workScore += 1) : null, child: const Text('작업! (+1점)')),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _workTimeLeft > 0 ? null : _startWorkMiniGame, child: const Text('아르바이트 시작')),
          ],
        ),
      ),
    );
  }

  Widget _shopPage() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('의상 상점 (착용 시 전신 외형/매력 변화)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._outfits.map((o) => Card(
              child: ListTile(
                leading: SizedBox(width: 42, height: 52, child: SvgPicture.asset(o.avatarAsset)),
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
                          .map((c) => OutlinedButton(onPressed: () => _buyGift(item, c), child: Text('${c.name}에게 선물')))
                          .toList(),
                    ),
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
        const Text('호감도 구간에 따라 랜덤 이벤트 연출이 달라집니다.'),
        const SizedBox(height: 8),
        ..._characters.map((c) => Card(
              child: ListTile(
                leading: SizedBox(width: 40, height: 54, child: SvgPicture.asset(c.fullBodyAsset)),
                title: Text('${c.name} (${c.role})'),
                subtitle: Text('호감도 ${c.affection}'),
                trailing: FilledButton(onPressed: () => _dateRandom(c), child: const Text('데이트')),
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
