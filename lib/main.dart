import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

enum Expression { neutral, smile, angry, blush, sad }
enum TransitionPreset { fade, slide, flash }
enum WorkMiniGame { herbSort, smithTiming, haggling }

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

class _Sparkle {
  _Sparkle({required this.id, required this.x, required this.y, required this.icon, required this.color});
  final int id;
  final double x;
  final double y;
  final IconData icon;
  final Color color;
}

class GameShell extends StatefulWidget {
  const GameShell({super.key});

  @override
  State<GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<GameShell> {
  static const _saveKey = 'vn_save_v7';
  final Random _random = Random();

  int _menuIndex = 0;
  int _gold = 120;
  int _storyIndex = 0;
  int _baseCharm = 12;
  bool _loaded = false;
  bool _inStoryScene = false;

  bool _autoPlay = false;
  bool _skipTyping = false;
  bool _lineCompleted = true;
  String _visibleLine = '';
  Timer? _typingTimer;

  WorkMiniGame _selectedWork = WorkMiniGame.herbSort;
  int _workTimeLeft = 0;
  int _workScore = 0;
  String _herbTarget = '라벤더';
  double _smithMeter = 0.0;
  bool _smithDirForward = true;
  double _hagglingTarget = 52;
  double _hagglingOffer = 52;
  Timer? _workTimer;

  int _sceneKey = 0;
  TransitionPreset _transitionPreset = TransitionPreset.fade;
  String _cameraSeed = '0';

  String _equippedOutfitId = 'default';
  String? _endingCharacterName;
  final List<String> _logs = [];
  final List<_Sparkle> _sparkles = [];
  final Map<String, int> _lastDelta = {};

  final Map<String, Expression> _expressions = {};

  final List<Character> _characters = [
    Character(
      name: '엘리안',
      role: '왕실 근위대장',
      fullBodyAsset: 'assets/generated/elian/001-full-body-handsome-male-knight-romance-w.png',
      description: '엄격하지만 당신 앞에서는 무너지는 기사.',
    ),
    Character(
      name: '루시안',
      role: '궁정 마도학자',
      fullBodyAsset: 'assets/generated/lucian/001-full-body-beautiful-male-mage-scholar-ro.png',
      description: '이성과 감정 사이에서 흔들리는 전략가.',
    ),
    Character(
      name: '세레나',
      role: '귀족 외교관',
      fullBodyAsset: 'assets/generated/serena/001-full-body-elegant-female-diplomat-romanc.png',
      description: '우아한 미소 뒤에 칼날을 숨긴 외교가.',
      affection: 26,
    ),
  ];

  final List<OutfitItem> _outfits = [
    OutfitItem(id: 'default', name: '수수한 여행복', price: 0, charmBonus: 0, avatarAsset: 'assets/generated/heroine/001-full-body-2d-romance-webtoon-style-heroi.png'),
    OutfitItem(id: 'noble_dress', name: '귀족 연회 드레스', price: 220, charmBonus: 4, avatarAsset: 'assets/generated/outfit_noble/001-full-body-female-protagonist-romance-web.png'),
    OutfitItem(id: 'ranger_look', name: '숲의 레인저 복장', price: 180, charmBonus: 3, avatarAsset: 'assets/generated/outfit_ranger/001-full-body-female-protagonist-romance-web.png'),
    OutfitItem(id: 'moon_gown', name: '월광 궁정 예복', price: 380, charmBonus: 7, avatarAsset: 'assets/generated/outfit_moon/001-full-body-female-protagonist-romance-web.png'),
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
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
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
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '세레나',
      rightCharacter: '엘리안',
      choices: [
        StoryChoice(label: '[세레나] 외교 연합을 제안한다', mainTarget: '세레나', mainDelta: 11, sideTarget: '엘리안', sideDelta: -1, result: '세레나는 당신에게만 비밀을 공유했다.'),
        StoryChoice(label: '[엘리안] 시민 앞에서 함께 춤춘다', mainTarget: '엘리안', mainDelta: 9, sideTarget: '세레나', sideDelta: 1, result: '엘리안의 눈빛이 흔들렸다.'),
      ],
    ),
    StoryBeat(
      title: '마탑의 밤',
      speaker: '루시안',
      line: '금지된 결계는 누군가의 미래를 살리고, 또 누군가의 신념을 부순다.',
      backgroundAsset: 'assets/generated/bg_tower/001-mystic-mage-tower-observatory-at-midnigh.png',
      leftCharacter: '루시안',
      rightCharacter: '세레나',
      showLeft: true,
      showRight: false,
      choices: [
        StoryChoice(label: '[루시안] 실험을 허가하고 끝까지 함께한다', mainTarget: '루시안', mainDelta: 12, sideTarget: '엘리안', sideDelta: -2, result: '루시안은 감정을 숨기지 않았다.'),
        StoryChoice(label: '[세레나] 시민 안전을 우선해 실험을 중지시킨다', mainTarget: '세레나', mainDelta: 10, sideTarget: '루시안', sideDelta: -2, result: '세레나는 당신의 결단에 존경을 보냈다.'),
      ],
    ),
    StoryBeat(
      title: '결전 전야',
      speaker: '나레이션',
      line: '전쟁의 북소리가 다가온다. 마지막 밤, 누구의 손을 잡을 것인가.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '엘리안',
      rightCharacter: '루시안',
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
    for (final c in _characters) {
      _expressions[c.name] = Expression.neutral;
    }
    _load();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _workTimer?.cancel();
    super.dispose();
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
      _storySelections = ((m['storySelections'] as List<dynamic>?) ?? List.filled(_story.length, null)).map<int?>((e) => e == null ? null : e as int).toList();
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

    _beginBeatLine();

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

  void _playClick() => SystemSound.play(SystemSoundType.click);
  void _playReward() => SystemSound.play(SystemSoundType.alert);

  int _scaledGain(int base) => base + (_totalCharm ~/ 5);

  void _setExpression(String name, Expression expression) {
    _expressions[name] = expression;
  }

  void _beginBeatLine() {
    _typingTimer?.cancel();
    final line = _story[_storyIndex].line;
    if (_skipTyping) {
      setState(() {
        _visibleLine = line;
        _lineCompleted = true;
      });
      return;
    }

    setState(() {
      _visibleLine = '';
      _lineCompleted = false;
    });

    int i = 0;
    final ms = _autoPlay ? 12 : 22;
    _typingTimer = Timer.periodic(Duration(milliseconds: ms), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (i >= line.length) {
        t.cancel();
        setState(() => _lineCompleted = true);
        return;
      }
      i += 1;
      setState(() => _visibleLine = line.substring(0, i));
    });
  }

  Future<void> _checkEndingIfNeeded(Character c) async {
    if (_endingCharacterName != null || c.affection < 100) return;
    _endingCharacterName = c.name;
    _logs.insert(0, '[엔딩] ${c.name} 루트 확정 (최초 100 달성)');
    _playReward();
    await _save();

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('엔딩 확정'),
        content: Text('${c.name}의 호감도가 가장 먼저 100에 도달했습니다.\n\n${c.name} 엔딩 루트가 확정됩니다.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  Future<void> _addAffection(Character target, int delta, String logPrefix) async {
    target.affection = (target.affection + delta).clamp(0, 100);
    _lastDelta[target.name] = delta;
    _logs.insert(0, '$logPrefix ${target.name} +$delta');
    _triggerSparkles(target.name, positive: delta >= 0);
    await _checkEndingIfNeeded(target);

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _lastDelta.remove(target.name);
      });
    });
  }

  void _triggerSparkles(String targetName, {required bool positive}) {
    final leftName = _story[_storyIndex].leftCharacter;
    final isLeft = targetName == leftName;
    for (int i = 0; i < 5; i++) {
      _sparkles.add(
        _Sparkle(
          id: DateTime.now().microsecondsSinceEpoch + i,
          x: (isLeft ? 130 : 760) + _random.nextDouble() * 90,
          y: 240 + _random.nextDouble() * 140,
          icon: positive ? Icons.auto_awesome : Icons.flash_on,
          color: positive ? Colors.pinkAccent : Colors.lightBlueAccent,
        ),
      );
    }
    setState(() {});

    Future.delayed(const Duration(milliseconds: 520), () {
      if (!mounted) return;
      setState(() {
        _sparkles.clear();
      });
    });
  }

  Future<void> _pickStoryChoice(StoryChoice choice, int choiceIndex) async {
    if (_endingCharacterName != null) return;
    _playClick();

    _storySelections[_storyIndex] = choiceIndex;

    final main = _characterByName(choice.mainTarget);
    await _addAffection(main, _scaledGain(choice.mainDelta), '[스토리]');
    _setExpression(main.name, Expression.smile);

    if (choice.sideTarget != null) {
      final side = _characterByName(choice.sideTarget!);
      side.affection = (side.affection + choice.sideDelta).clamp(0, 100);
      _setExpression(side.name, choice.sideDelta < 0 ? Expression.angry : Expression.neutral);
    }

    _logs.insert(0, '[대사] ${choice.result}');

    if (_storyIndex < _story.length - 1) {
      _storyIndex += 1;
      _sceneKey += 1;
      _cameraSeed = '${_random.nextDouble()}';
      _transitionPreset = choice.sideDelta < 0 ? TransitionPreset.flash : TransitionPreset.slide;
    }

    _beginBeatLine();
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
    _playClick();
    _gold -= item.price;
    await _addAffection(target, _scaledGain(item.affectionBoost), '[상점] ${item.name} 선물 ->');
    _setExpression(target.name, Expression.blush);
    await _save();
    setState(() {});
  }

  Future<void> _buyOutfit(OutfitItem item) async {
    if (_gold < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('골드가 부족합니다.')));
      return;
    }
    _playClick();
    _gold -= item.price;
    _equippedOutfitId = item.id;
    _logs.insert(0, '[장착] ${item.name} 착용 (매력 +${item.charmBonus})');
    await _save();
    setState(() {});
  }

  void _prepareWorkRound() {
    switch (_selectedWork) {
      case WorkMiniGame.herbSort:
        const herbs = ['라벤더', '로즈마리', '박하', '세이지'];
        _herbTarget = herbs[_random.nextInt(herbs.length)];
        break;
      case WorkMiniGame.smithTiming:
        _smithMeter = _random.nextDouble();
        _smithDirForward = _random.nextBool();
        break;
      case WorkMiniGame.haggling:
        _hagglingTarget = 35 + _random.nextInt(31).toDouble();
        _hagglingOffer = 20 + _random.nextInt(61).toDouble();
        break;
    }
  }

  void _startWorkMiniGame() {
    _playClick();
    _workTimer?.cancel();
    _workTimeLeft = 20;
    _workScore = 0;
    _prepareWorkRound();

    _workTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
      if (!mounted || _menuIndex != 2) {
        timer.cancel();
        return;
      }

      if (_selectedWork == WorkMiniGame.smithTiming) {
        final delta = 0.03;
        if (_smithDirForward) {
          _smithMeter += delta;
          if (_smithMeter >= 1) {
            _smithMeter = 1;
            _smithDirForward = false;
          }
        } else {
          _smithMeter -= delta;
          if (_smithMeter <= 0) {
            _smithMeter = 0;
            _smithDirForward = true;
          }
        }
      }

      if (timer.tick % 8 == 0) {
        _workTimeLeft -= 1;
        if (_workTimeLeft <= 0) {
          timer.cancel();
          _finishWorkMiniGame();
          return;
        }
      }
      setState(() {});
    });

    setState(() {});
  }

  Future<void> _finishWorkMiniGame() async {
    if (!mounted) return;
    final reward = 30 + (_workScore * 9);
    _gold += reward;
    _logs.insert(0, '[아르바이트:${_selectedWork.name}] 점수 $_workScore, 골드 +$reward');
    _playReward();
    await _save();
    if (_menuIndex == 2) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('아르바이트 완료! +$reward G')));
      setState(() {});
    }
  }

  void _workActionHerb(String herb) {
    if (_workTimeLeft <= 0) return;
    if (herb == _herbTarget) {
      _workScore += 2;
      _playReward();
    } else {
      _workScore = max(0, _workScore - 1);
      _playClick();
    }
    _prepareWorkRound();
    setState(() {});
  }

  void _workActionSmith() {
    if (_workTimeLeft <= 0) return;
    final dist = (_smithMeter - 0.5).abs();
    int gain;
    if (dist < 0.07) {
      gain = 4;
    } else if (dist < 0.15) {
      gain = 2;
    } else {
      gain = 1;
    }
    _workScore += gain;
    _playClick();
    setState(() {});
  }

  void _workActionHaggling() {
    if (_workTimeLeft <= 0) return;
    final diff = (_hagglingOffer - _hagglingTarget).abs();
    if (diff <= 2) {
      _workScore += 4;
      _playReward();
    } else if (diff <= 6) {
      _workScore += 2;
      _playClick();
    } else {
      _workScore = max(0, _workScore - 1);
    }
    _prepareWorkRound();
    setState(() {});
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
    _playReward();
    await _addAffection(target, gain, '[데이트]');
    _setExpression(target.name, Expression.blush);
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

  Color _moodOverlay() {
    if (_endingCharacterName != null) return Colors.pink.withOpacity(0.14);
    final selected = _storySelections[_storyIndex];
    if (selected == null) return Colors.black.withOpacity(0.30);
    final target = _story[_storyIndex].choices[selected].mainTarget;
    if (target == '엘리안') return Colors.orange.withOpacity(0.10);
    if (target == '루시안') return Colors.blue.withOpacity(0.13);
    return Colors.purple.withOpacity(0.12);
  }

  Widget _fullBodySprite(String asset, {double width = 220}) {
    final isSvg = asset.endsWith('.svg');
    return SizedBox(
      width: width,
      height: width * 1.45,
      child: isSvg ? SvgPicture.asset(asset, fit: BoxFit.contain) : Image.asset(asset, fit: BoxFit.contain),
    );
  }

  Widget _characterImageWithExpression(Character c, {double width = 170}) {
    final exp = _expressions[c.name] ?? Expression.neutral;
    ColorFilter? filter;
    switch (exp) {
      case Expression.smile:
        filter = const ColorFilter.mode(Color(0x14FFD54F), BlendMode.overlay);
        break;
      case Expression.angry:
        filter = const ColorFilter.mode(Color(0x26FF5252), BlendMode.overlay);
        break;
      case Expression.blush:
        filter = const ColorFilter.mode(Color(0x22F06292), BlendMode.overlay);
        break;
      case Expression.sad:
        filter = const ColorFilter.mode(Color(0x2A90CAF9), BlendMode.overlay);
        break;
      case Expression.neutral:
        filter = null;
        break;
    }

    final sprite = _fullBodySprite(c.fullBodyAsset, width: width);
    return filter == null ? sprite : ColorFiltered(colorFilter: filter, child: sprite);
  }

  Widget _deltaBadge(String name) {
    final delta = _lastDelta[name];
    if (delta == null) return const SizedBox.shrink();
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Text(
        key: ValueKey(delta),
        delta >= 0 ? '+$delta' : '$delta',
        style: TextStyle(color: delta >= 0 ? Colors.lightGreenAccent : Colors.redAccent, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _objectivePanel() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.42), borderRadius: BorderRadius.circular(10)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('목표', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          SizedBox(height: 3),
          Text('1) 호감도 100 선점', style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text('2) 분기 루트 개방', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

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
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: Tween<double>(begin: 0.985, end: 1).animate(animation), child: child),
        ),
        child: KeyedSubtree(key: ValueKey(_menuIndex), child: _buildMenuPage(_menuIndex)),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _menuIndex,
        onDestinationSelected: (v) {
          _playClick();
          setState(() => _menuIndex = v);
        },
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

  Widget _buildMenuPage(int index) {
    switch (index) {
      case 0:
        return _homePage();
      case 1:
        return _storyRootPage();
      case 2:
        return _workPage();
      case 3:
        return _shopPage();
      case 4:
        return _datePage();
      case 5:
      default:
        return _logPage();
    }
  }

  Widget _homePage() {
    final outfit = _outfits.firstWhere((e) => e.id == _equippedOutfitId);
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          height: 290,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned.fill(child: Image.asset('assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png', fit: BoxFit.cover)),
                Positioned.fill(child: Container(color: Colors.black.withOpacity(0.28))),
                Positioned(left: 12, bottom: 0, child: _fullBodySprite(_playerAvatar, width: 180)),
                Positioned(
                  right: 14,
                  top: 20,
                  child: Container(
                    width: 235,
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
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: _characters
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          SizedBox(width: 30, child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                          const SizedBox(width: 6),
                          Expanded(child: LinearProgressIndicator(value: c.affection / 100, minHeight: 8)),
                          const SizedBox(width: 8),
                          SizedBox(width: 30, child: Text('${c.affection}')),
                          SizedBox(width: 30, child: _deltaBadge(c.name)),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                const Text('현재 장착 전신 프리뷰', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Center(child: _fullBodySprite(_playerAvatar, width: 200)),
                const SizedBox(height: 8),
                const Text('하단 메뉴(스토리/아르바이트/상점/데이트)로 이동하세요.'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        _playClick();
        onTap();
      },
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
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: _inStoryScene
          ? KeyedSubtree(key: const ValueKey('story_scene'), child: _storyScenePage())
          : KeyedSubtree(key: const ValueKey('story_map'), child: _storyProgressPage()),
    );
  }

  Widget _storyProgressPage() {
    final cleared = _storySelections.where((e) => e != null).length;
    final preview = _story[_storyIndex];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 210,
            child: Stack(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: SizedBox.expand(
                    key: ValueKey(preview.backgroundAsset),
                    child: Image.asset(preview.backgroundAsset, fit: BoxFit.cover),
                  ),
                ),
                Positioned.fill(child: Container(color: Colors.black.withOpacity(0.35))),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('EP ${_storyIndex + 1}. ${preview.title}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text(preview.line, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('스토리 진행도 (아래 → 위)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 6),
                Text('클리어: $cleared / ${_story.length}'),
                if (_endingCharacterName != null) Text('확정 엔딩: $_endingCharacterName', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _branchRouteMap(),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {
                    _playClick();
                    setState(() {
                      _inStoryScene = true;
                      _sceneKey += 1;
                      _transitionPreset = TransitionPreset.fade;
                    });
                    _beginBeatLine();
                  },
                  child: Text(cleared == 0 ? '스토리 시작' : '이 스텝부터 진행'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _branchRouteMap() {
    // bottom -> top progression with multi-branch clickable nodes
    const mapH = 520.0;
    const laneX = [48.0, 168.0, 288.0];

    final nodes = <Map<String, int>>[
      {'id': 0, 'beat': 0, 'lane': 1, 'step': 0},
      {'id': 1, 'beat': 1, 'lane': 0, 'step': 1},
      {'id': 2, 'beat': 1, 'lane': 2, 'step': 1},
      {'id': 3, 'beat': 2, 'lane': 0, 'step': 2},
      {'id': 4, 'beat': 2, 'lane': 1, 'step': 2},
      {'id': 5, 'beat': 2, 'lane': 2, 'step': 2},
      {'id': 6, 'beat': 3, 'lane': 1, 'step': 3},
      {'id': 7, 'beat': 3, 'lane': 2, 'step': 3},
    ];

    Offset nodePos(Map<String, int> n) {
      final x = laneX[n['lane']!];
      final y = mapH - 54 - (n['step']! * 130);
      return Offset(x, y);
    }

    final links = [
      [0, 1], [0, 2],
      [1, 3], [1, 4],
      [2, 4], [2, 5],
      [3, 6], [4, 6], [4, 7], [5, 7],
    ];

    return Container(
      height: mapH,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0F2340),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RouteLinkPainter(
                nodes: nodes,
                links: links,
                nodePos: nodePos,
                selectedBeat: _storyIndex,
              ),
            ),
          ),
          ...nodes.map((n) {
            final beat = n['beat']!;
            final pos = nodePos(n);
            final done = _storySelections[beat] != null;
            final selected = beat == _storyIndex;
            return Positioned(
              left: pos.dx,
              top: pos.dy,
              child: GestureDetector(
                onTap: () {
                  _playClick();
                  setState(() => _storyIndex = beat);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? Colors.amber : (done ? const Color(0xFF8A6B4D) : const Color(0xFF364A66)),
                    border: Border.all(color: Colors.white70),
                    boxShadow: selected ? [const BoxShadow(color: Colors.amberAccent, blurRadius: 8)] : null,
                  ),
                  child: Text('${n['id']! + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _storyScenePage() {
    final beat = _story[_storyIndex];
    final left = _characterByName(beat.leftCharacter);
    final right = _characterByName(beat.rightCharacter);

    Widget transitionBuilder(Widget child, Animation<double> animation) {
      switch (_transitionPreset) {
        case TransitionPreset.slide:
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(animation), child: child),
          );
        case TransitionPreset.flash:
          return FadeTransition(
            opacity: animation,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 1.14, end: 1),
              duration: const Duration(milliseconds: 210),
              builder: (_, v, c) => ColorFiltered(colorFilter: ColorFilter.mode(Colors.white.withOpacity(v - 1), BlendMode.screen), child: c),
              child: child,
            ),
          );
        case TransitionPreset.fade:
          return FadeTransition(opacity: animation, child: child);
      }
    }

    return Stack(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: transitionBuilder,
          child: KeyedSubtree(
            key: ValueKey(_sceneKey),
            child: Stack(
              children: [
                Positioned.fill(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 1.08, end: 1),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOut,
                    builder: (_, scale, __) => Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: Transform.translate(
                        offset: Offset((_cameraSeed.hashCode % 8) - 4, 0),
                        child: Image.asset(beat.backgroundAsset, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(child: Container(color: _moodOverlay())),
                Positioned(top: 10, left: 10, child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.4), foregroundColor: Colors.white),
                  onPressed: () => setState(() => _inStoryScene = false),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('스토리 맵'),
                )),
                Positioned(top: 10, right: 10, child: _objectivePanel()),
                Positioned(left: 8, bottom: 130, child: _animatedCharacterCard(left, visible: beat.showLeft, fromLeft: true)),
                Positioned(right: 8, bottom: 130, child: _animatedCharacterCard(right, visible: beat.showRight, fromLeft: false)),
                Positioned(left: 0, right: 0, bottom: 0, child: _dialogWindow(beat)),
              ],
            ),
          ),
        ),
        ..._sparkles.map((s) => Positioned(
              left: s.x,
              top: s.y,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.4, end: 1),
                duration: const Duration(milliseconds: 450),
                builder: (_, v, __) => Opacity(opacity: 1 - (v - 0.4), child: Transform.scale(scale: v, child: Icon(s.icon, color: s.color, size: 18))),
              ),
            )),
      ],
    );
  }

  Widget _animatedCharacterCard(Character c, {required bool visible, required bool fromLeft}) {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      offset: visible ? Offset.zero : Offset(fromLeft ? -0.18 : 0.18, 0.10),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 290),
        opacity: visible ? 1 : 0,
        child: GestureDetector(
          onTap: () async {
            if (!visible || _endingCharacterName != null) return;
            _playClick();
            await _addAffection(c, 1, '[상호작용]');
            await _save();
            if (mounted) setState(() {});
          },
          child: Container(
            width: 210,
            height: 330,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.36), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white24)),
            child: Column(
              children: [
                Expanded(child: _characterImageWithExpression(c, width: 170)),
                Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text('❤ ${c.affection}', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(width: 8),
                  _deltaBadge(c.name),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dialogWindow(StoryBeat beat) {
    return GestureDetector(
      onTap: () {
        if (_lineCompleted) return;
        _typingTimer?.cancel();
        setState(() {
          _visibleLine = beat.line;
          _lineCompleted = true;
        });
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        child: Container(
          key: ValueKey('dialog_${_storyIndex}_$_lineCompleted'),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          color: Colors.black.withOpacity(0.78),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('${beat.speaker} · ${beat.title}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700))),
                    IconButton(
                      onPressed: () {
                        _playClick();
                        setState(() => _autoPlay = !_autoPlay);
                        _beginBeatLine();
                      },
                      icon: Icon(Icons.play_circle_fill, color: _autoPlay ? Colors.greenAccent : Colors.white54),
                      tooltip: '오토',
                    ),
                    IconButton(
                      onPressed: () {
                        _playClick();
                        setState(() => _skipTyping = !_skipTyping);
                        _beginBeatLine();
                      },
                      icon: Icon(Icons.fast_forward, color: _skipTyping ? Colors.greenAccent : Colors.white54),
                      tooltip: '스킵',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_visibleLine, style: const TextStyle(color: Colors.white, fontSize: 15)),
                const SizedBox(height: 10),
                if (_lineCompleted)
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
                  )
                else
                  const Text('탭하여 대사 넘기기', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _workPage() {
    const herbs = ['라벤더', '로즈마리', '박하', '세이지'];

    Widget gameBody;
    if (_selectedWork == WorkMiniGame.herbSort) {
      gameBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('지시된 약초를 고르세요: $_herbTarget', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: herbs
                .map((h) => OutlinedButton(onPressed: _workTimeLeft > 0 ? () => _workActionHerb(h) : null, child: Text(h)))
                .toList(),
          ),
        ],
      );
    } else if (_selectedWork == WorkMiniGame.smithTiming) {
      gameBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('대장간 단조: 중앙(황금 구간)에 맞춰 타격!', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Stack(
            children: [
              Container(height: 20, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              Positioned(left: 140, child: Container(width: 40, height: 20, decoration: BoxDecoration(color: Colors.amber.shade300, borderRadius: BorderRadius.circular(8)))),
              Positioned(left: _smithMeter * 320, child: Container(width: 8, height: 20, color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton(onPressed: _workTimeLeft > 0 ? _workActionSmith : null, child: const Text('망치 내리치기')),
        ],
      );
    } else {
      gameBody = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('시장 흥정: 목표 ${_hagglingTarget.toStringAsFixed(0)}G 근처로 제시', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Slider(
            min: 20,
            max: 80,
            divisions: 60,
            value: _hagglingOffer,
            label: '${_hagglingOffer.toStringAsFixed(0)}G',
            onChanged: _workTimeLeft > 0 ? (v) => setState(() => _hagglingOffer = v) : null,
          ),
          Text('현재 제시가: ${_hagglingOffer.toStringAsFixed(0)}G'),
          const SizedBox(height: 8),
          FilledButton(onPressed: _workTimeLeft > 0 ? _workActionHaggling : null, child: const Text('흥정 제시')),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('중세 아르바이트 미니게임', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SegmentedButton<WorkMiniGame>(
          segments: const [
            ButtonSegment(value: WorkMiniGame.herbSort, label: Text('약초 분류'), icon: Icon(Icons.spa)),
            ButtonSegment(value: WorkMiniGame.smithTiming, label: Text('대장간 단조'), icon: Icon(Icons.hardware)),
            ButtonSegment(value: WorkMiniGame.haggling, label: Text('시장 흥정'), icon: Icon(Icons.payments)),
          ],
          selected: {_selectedWork},
          onSelectionChanged: (s) {
            _playClick();
            setState(() => _selectedWork = s.first);
            if (_workTimeLeft > 0) _prepareWorkRound();
          },
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('남은 시간: $_workTimeLeft초  |  점수: $_workScore'),
                const SizedBox(height: 10),
                gameBody,
                const SizedBox(height: 10),
                OutlinedButton(onPressed: _workTimeLeft > 0 ? null : _startWorkMiniGame, child: const Text('아르바이트 시작')),
              ],
            ),
          ),
        ),
      ],
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
                leading: SizedBox(width: 42, height: 52, child: _fullBodySprite(o.avatarAsset, width: 34)),
                title: Text('${o.name}  (+${o.charmBonus} 매력)'),
                subtitle: Text(o.price == 0 ? '기본 의상' : '${o.price} G'),
                trailing: FilledButton(
                  onPressed: o.id == _equippedOutfitId
                      ? null
                      : () {
                          if (o.price == 0) {
                            _playClick();
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
                      children: _characters.map((c) => OutlinedButton(onPressed: () => _buyGift(item, c), child: Text('${c.name}에게 선물'))).toList(),
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
                leading: SizedBox(width: 40, height: 54, child: _characterImageWithExpression(c, width: 36)),
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

class _RouteLinkPainter extends CustomPainter {
  _RouteLinkPainter({
    required this.nodes,
    required this.links,
    required this.nodePos,
    required this.selectedBeat,
  });

  final List<Map<String, int>> nodes;
  final List<List<int>> links;
  final Offset Function(Map<String, int>) nodePos;
  final int selectedBeat;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = const Color(0x66C0B090)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final active = Paint()
      ..color = const Color(0xCCFFE08A)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    Map<String, int> byId(int id) => nodes.firstWhere((e) => e['id'] == id);

    for (final l in links) {
      final a = byId(l[0]);
      final b = byId(l[1]);
      final p1 = nodePos(a) + const Offset(17, 17);
      final p2 = nodePos(b) + const Offset(17, 17);
      final cp = Offset((p1.dx + p2.dx) / 2, p1.dy - 22);

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(cp.dx, cp.dy, p2.dx, p2.dy);

      final isActive = (a['beat'] == selectedBeat) || (b['beat'] == selectedBeat);
      canvas.drawPath(path, isActive ? active : base);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinkPainter oldDelegate) {
    return oldDelegate.selectedBeat != selectedBeat;
  }
}
