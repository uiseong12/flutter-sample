import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v64;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'minigame/flame_dot_game.dart';

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
enum WorkMiniGame { herbSort, smithTiming, haggling, courierRun, dateDance, gardenWalk }
enum RelationshipState { strange, favorable, trust, shaken, bond, alliedLovers, oath }
enum ChoiceKind { free, condition, premium }

class UnlockDecision {
  const UnlockDecision({required this.unlocked, required this.reason});

  final bool unlocked;
  final String reason;
}

class EndingDecision {
  const EndingDecision({required this.id, required this.type});

  final String id;
  final String type;
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
    this.kind = ChoiceKind.free,
  });

  final String label;
  final String mainTarget;
  final int mainDelta;
  final String result;
  final String? sideTarget;
  final int sideDelta;
  final ChoiceKind kind;
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
  int _premiumTokens = 0;
  int _storyIndex = 0;
  int _baseCharm = 12;
  bool _loaded = false;
  bool _inStoryScene = false;
  bool _endingEvaluated = false;

  bool _autoPlay = false;
  bool _skipTyping = false;
  bool _lineCompleted = true;
  String _visibleLine = '';
  Timer? _typingTimer;

  WorkMiniGame _selectedWork = WorkMiniGame.herbSort;
  int _workTimeLeft = 0;
  int _workScore = 0;
  int _combo = 0;
  bool _failFlash = false;
  String _herbTarget = '라벤더';
  double _smithMeter = 0.0;
  bool _smithDirForward = true;
  double _hagglingTarget = 52;
  double _hagglingOffer = 52;
  double _marketCursor = 0.0;
  bool _marketDirForward = true;
  int _danceNeed = 0;
  int _danceStreak = 0;

  Point<int> _herbPos = const Point(3, 3);
  List<List<int>> _herbGrid = List.generate(7, (_) => List.filled(7, 0));
  Point<int> _courierPos = const Point(0, 3);
  Set<String> _courierDocs = <String>{};
  List<Point<int>> _guards = const [Point(2, 2), Point(4, 4), Point(5, 1)];
  Point<int> _gardenPos = const Point(3, 3);
  Set<String> _gardenHearts = <String>{};
  Set<String> _gardenThorns = <String>{};

  Timer? _workTimer;

  int _sceneKey = 0;
  int _animTick = 0;
  String? _cutinCharacter;
  String _cutinLine = '좋아, 계속 가자!';
  int _cutinTicks = 0;
  TransitionPreset _transitionPreset = TransitionPreset.fade;
  String _cameraSeed = '0';

  String _equippedOutfitId = 'default';
  String? _endingCharacterName;
  String? _lockedRouteCharacterName;
  String? _endingRuleId;
  String? _endingRuleType;
  bool _showAffectionOverlay = false;
  bool _menuOverlayOpen = false;
  final List<String> _logs = [];
  final List<_Sparkle> _sparkles = [];
  final Map<String, int> _lastDelta = {};
  final Map<String, String> _dateModeByCharacter = {};
  final Map<int, List<Map<String, dynamic>>> _nodeDialogues = {};
  final Map<int, List<Map<String, dynamic>>> _nodeCheckpoints = {};
  final Map<String, Map<int, List<Map<String, dynamic>>>> _routeNodeDialogues = {'elian': {}, 'lucian': {}, 'serena': {}};
  final Map<String, Map<int, List<Map<String, dynamic>>>> _routeNodeCheckpoints = {'elian': {}, 'lucian': {}, 'serena': {}};
  final Map<int, Set<int>> _resolvedCheckpointAts = {};
  int _nodeDialogueIndex = 0;

  final Map<String, Expression> _expressions = {};
  final Map<String, RelationshipState> _relationshipStates = {};
  final Map<String, int> _politicalStats = {
    'legitimacy': 30,
    'economy': 30,
    'publicTrust': 30,
    'military': 30,
    'surveillance': 10,
  };
  final List<int> _surveillanceTimeline = [10, 10, 10, 10, 10];
  final Map<String, bool> _keyFlags = {
    'publicly_supported_me': false,
    'saved_in_ceremony': false,
    'recipeUnlocked': false,
    'guild_hostile': false,
    'guild_backed': false,
  };
  final Set<String> _evidenceOwned = <String>{};
  final Set<String> _costumeTags = <String>{};
  Map<String, dynamic> _unlockRules = {};
  Map<String, dynamic> _endingRules = {};
  Map<String, dynamic> _statBalanceTable = {};
  Map<String, dynamic> _premiumCatalog = {};
  Map<String, dynamic> _unlockContentSchema = {};
  final Map<String, int> _dailyAdViews = {};

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
      title: '1-1 계약약혼',
      speaker: '나레이션',
      line: '몰락귀족 여주 이세라는 생존을 위해 기사단장과 계약약혼을 맺는다. 약혼식 직후 복식 위반 고발장이 날아든다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[엘리안] 법정에 즉시 항변', mainTarget: '엘리안', mainDelta: 9, result: '엘리안은 검이 아닌 법전을 들었다.'),
        StoryChoice(label: '[세레나] 귀족 살롱 여론전', mainTarget: '세레나', mainDelta: 9, result: '세레나는 웃으며 귀족들의 방향을 틀었다.'),
      ],
    ),
    StoryBeat(
      title: '1-2 조작된 염색샘플',
      speaker: '세레나',
      line: '위반 증거로 제출된 염색 샘플에서 조작 흔적이 드러난다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '세레나',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[루시안] 시약 감정서 제출', mainTarget: '루시안', mainDelta: 8, result: '루시안은 염료의 시간을 증명했다.'),
        StoryChoice(label: '[세레나] 서기관 진술 확보', mainTarget: '세레나', mainDelta: 8, result: '봉인함 교체 시간이 밝혀졌다.'),
      ],
    ),
    StoryBeat(
      title: '1-3 첫 반격',
      speaker: '나레이션',
      line: '복식법정청 내부자가 법을 사유화한 정황이 드러난다.',
      backgroundAsset: 'assets/generated/bg_tower/001-mystic-mage-tower-observatory-at-midnigh.png',
      leftCharacter: '엘리안',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[엘리안] 내부고발자 보호', mainTarget: '엘리안', mainDelta: 9, result: '증언이 살아남아 반격의 문이 열렸다.'),
        StoryChoice(label: '[루시안] 장부 암호 해독', mainTarget: '루시안', mainDelta: 9, result: '숫자 뒤에 숨은 손이 드러났다.'),
      ],
    ),
    StoryBeat(
      title: '2-1 공개 망신의 날',
      speaker: '나레이션',
      line: '궁정은 복식법 위반을 무기로 여주의 가문 재산까지 압류하려 든다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[엘리안] 군납선 보호', mainTarget: '엘리안', mainDelta: 9, result: '병참 라인이 끊기지 않았다.'),
        StoryChoice(label: '[세레나] 의회파 분열', mainTarget: '세레나', mainDelta: 9, result: '표결판이 갈라졌다.'),
      ],
    ),
    StoryBeat(
      title: '2-2 길드 장부',
      speaker: '루시안',
      line: '직물·염색 길드의 장부 한 줄이 귀족전보다 치명적인 경제제재를 암시한다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '루시안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[루시안] 거래코드 해독', mainTarget: '루시안', mainDelta: 10, result: '가짜 보랏빛 유통선이 잡혔다.'),
        StoryChoice(label: '[세레나] 길드장 협약', mainTarget: '세레나', mainDelta: 8, result: '시장 가격이 우리 쪽으로 기울었다.'),
      ],
    ),
    StoryBeat(
      title: '2-3 감정 이전의 동맹',
      speaker: '엘리안',
      line: '두 사람은 감정보다 먼저 동맹을 선택한다. 그러나 시선은 이미 흔들린다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '엘리안',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[엘리안] 공개서약', mainTarget: '엘리안', mainDelta: 10, result: '방패와 서약이 같은 방향을 향했다.'),
        StoryChoice(label: '[루시안] 비밀서약', mainTarget: '루시안', mainDelta: 10, result: '침묵의 계약이 체결됐다.'),
      ],
    ),
    StoryBeat(
      title: '3-1 신판 소환',
      speaker: '나레이션',
      line: '여주가 준-신판 절차에 회부된다. 의식은 이미 판결이 정해진 연극 같다.',
      backgroundAsset: 'assets/generated/bg_tower/001-mystic-mage-tower-observatory-at-midnigh.png',
      leftCharacter: '루시안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[루시안] 절차 모순 제시', mainTarget: '루시안', mainDelta: 11, result: '제단의 규칙이 스스로 무너졌다.'),
        StoryChoice(label: '[세레나] 참관인 설득', mainTarget: '세레나', mainDelta: 9, result: '증언의 순서를 뒤집었다.'),
      ],
    ),
    StoryBeat(
      title: '3-2 물의 맹세문',
      speaker: '나레이션',
      line: '맹세문 필사가 사건 이후 잉크로 작성된 사실이 발견된다.',
      backgroundAsset: 'assets/generated/bg_tower/001-mystic-mage-tower-observatory-at-midnigh.png',
      leftCharacter: '엘리안',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[엘리안] 증인 호위', mainTarget: '엘리안', mainDelta: 10, result: '증인은 끝까지 살아서 말했다.'),
        StoryChoice(label: '[루시안] 잉크 연대측정', mainTarget: '루시안', mainDelta: 10, result: '문서가 거짓임이 확정됐다.'),
      ],
    ),
    StoryBeat(
      title: '3-3 공개 선언',
      speaker: '엘리안',
      line: '엘리안은 명예보다 여주 편에 서겠다고 공개 선언한다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[엘리안] 전군 앞 맹세', mainTarget: '엘리안', mainDelta: 12, result: '정치적 거래가 상호선택으로 바뀌었다.'),
        StoryChoice(label: '[세레나] 선언 수위 조절', mainTarget: '세레나', mainDelta: 9, result: '불씨를 남기고 화재를 피했다.'),
      ],
    ),
    StoryBeat(
      title: '4-1 왕실색 유출',
      speaker: '나레이션',
      line: '왕실 정통성 상징인 보랏빛 봉인 염료 조합이 유출됐다는 정보가 뜬다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '루시안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[루시안] 저장고 추적', mainTarget: '루시안', mainDelta: 10, result: '봉인 파편 이동경로를 포착했다.'),
        StoryChoice(label: '[세레나] 재단장 잠입', mainTarget: '세레나', mainDelta: 10, result: '가짜 보랏빛 공급처를 찾아냈다.'),
      ],
    ),
    StoryBeat(
      title: '4-2 왕실색 사용권',
      speaker: '세레나',
      line: '자주색은 패션이 아니라 왕위 정통성 장치였다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '세레나',
      rightCharacter: '엘리안',
      choices: [
        StoryChoice(label: '[세레나] 사용권 공표', mainTarget: '세레나', mainDelta: 11, result: '사칭 세력이 잠시 숨었다.'),
        StoryChoice(label: '[엘리안] 압수수색 강행', mainTarget: '엘리안', mainDelta: 11, result: '가짜 왕실복이 시장에서 사라졌다.'),
      ],
    ),
    StoryBeat(
      title: '4-3 배신의 밤',
      speaker: '루시안',
      line: '동맹의 배신처럼 보이는 선택이 모두를 갈라놓는다.',
      backgroundAsset: 'assets/generated/bg_tower/001-mystic-mage-tower-observatory-at-midnigh.png',
      leftCharacter: '루시안',
      rightCharacter: '엘리안',
      choices: [
        StoryChoice(label: '[루시안] 진짜 배후 추적', mainTarget: '루시안', mainDelta: 12, result: '배신은 미끼였고 배후는 더 깊었다.'),
        StoryChoice(label: '[엘리안] 즉시 처분', mainTarget: '엘리안', mainDelta: 8, result: 'BAD_ENDING: 성급한 처분으로 증거선이 끊기고 여주는 반역죄로 추방된다.'),
      ],
    ),
    StoryBeat(
      title: '5-1 은등회 파벌',
      speaker: '나레이션',
      line: '여성 공동체 은등회 내부 파벌이 폭발한다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '세레나',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[세레나] 중립 규칙안', mainTarget: '세레나', mainDelta: 11, result: '파벌의 칼끝이 잠시 거두어졌다.'),
        StoryChoice(label: '[루시안] 회계 조작 색출', mainTarget: '루시안', mainDelta: 9, result: '장부의 거짓이 걷혔다.'),
      ],
    ),
    StoryBeat(
      title: '5-2 질서와 변화',
      speaker: '엘리안',
      line: '남주는 질서를, 여주는 변화를 말한다. 가치관 충돌이 깊어진다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[엘리안] 단계적 개혁', mainTarget: '엘리안', mainDelta: 10, result: '결별은 피했지만 균열은 남았다.'),
        StoryChoice(label: '[세레나] 급진 개편', mainTarget: '세레나', mainDelta: 10, result: '구질서의 반격이 시작됐다.'),
      ],
    ),
    StoryBeat(
      title: '5-3 침묵의 거리',
      speaker: '나레이션',
      line: '말보다 긴 침묵이 둘 사이를 가른다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '엘리안',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[엘리안] 행동으로 사과', mainTarget: '엘리안', mainDelta: 12, result: '그는 말보다 먼저 방패가 되었다.'),
        StoryChoice(label: '[루시안] 논리로 봉합', mainTarget: '루시안', mainDelta: 9, result: '차가운 문장이 겨우 틈을 메웠다.'),
      ],
    ),
    StoryBeat(
      title: '6-1 사칭 대관식',
      speaker: '나레이션',
      line: '보랏빛 봉인 위조로 가짜 적통이 민심을 선점한다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '세레나',
      rightCharacter: '엘리안',
      choices: [
        StoryChoice(label: '[세레나] 민회 연설', mainTarget: '세레나', mainDelta: 12, result: '군중의 시선이 되돌아왔다.'),
        StoryChoice(label: '[엘리안] 대관식 봉쇄', mainTarget: '엘리안', mainDelta: 12, result: '왕관은 머리 위에 오르지 못했다.'),
      ],
    ),
    StoryBeat(
      title: '6-2 삼중 권력전',
      speaker: '루시안',
      line: '복식법정청·재무청·성직법정이 각자 다른 왕을 세우려 한다.',
      backgroundAsset: 'assets/generated/bg_tower/001-mystic-mage-tower-observatory-at-midnigh.png',
      leftCharacter: '루시안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[루시안] 3기관 동시협상', mainTarget: '루시안', mainDelta: 12, result: '한밤의 합의문이 새벽을 바꿨다.'),
        StoryChoice(label: '[세레나] 한 기관 희생', mainTarget: '세레나', mainDelta: 8, result: 'BAD_ENDING: 균형 붕괴로 내전이 조기 발화한다.'),
      ],
    ),
    StoryBeat(
      title: '6-3 반격의 직조',
      speaker: '나레이션',
      line: '길드-은등회-군수선을 한 줄로 엮어 반격을 시작한다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[엘리안] 군수선 보호', mainTarget: '엘리안', mainDelta: 11, result: '전선이 버텼다.'),
        StoryChoice(label: '[세레나] 시장 봉쇄', mainTarget: '세레나', mainDelta: 11, result: '적의 금고가 먼저 무너졌다.'),
      ],
    ),
    StoryBeat(
      title: '7-1 공개재판 쇼',
      speaker: '나레이션',
      line: '대관식 전야, 판결보다 연출이 중요한 밤의 공판이 열린다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '세레나',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[세레나] 의전 역이용', mainTarget: '세레나', mainDelta: 12, result: '무대의 중심이 바뀌었다.'),
        StoryChoice(label: '[루시안] 법리 반박', mainTarget: '루시안', mainDelta: 10, result: '새벽까지 판결이 미뤄졌다.'),
      ],
    ),
    StoryBeat(
      title: '7-2 프레임 전복',
      speaker: '엘리안',
      line: '여주는 의전·법·상징을 역이용해 정통성 프레임을 뒤집는다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[엘리안] 공동선언', mainTarget: '엘리안', mainDelta: 13, result: '거래가 아닌 선택으로 두 이름이 호명됐다.'),
        StoryChoice(label: '[세레나] 표결선 장악', mainTarget: '세레나', mainDelta: 11, result: '표결판이 완전히 뒤집혔다.'),
      ],
    ),
    StoryBeat(
      title: '7-3 상호선택',
      speaker: '나레이션',
      line: '둘의 관계가 정치적 거래가 아닌 상호선택임을 선언한다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '엘리안',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[엘리안] 공개 고백문', mainTarget: '엘리안', mainDelta: 14, result: '왕국은 사랑을 조약처럼 읽었다.'),
        StoryChoice(label: '[루시안] 비공개 서약', mainTarget: '루시안', mainDelta: 10, result: '진심은 남았지만 민심은 흔들렸다.'),
      ],
    ),
    StoryBeat(
      title: '8-1 봉인문서고',
      speaker: '루시안',
      line: '건국기 문서에서 불편한 진실이 드러난다.',
      backgroundAsset: 'assets/generated/bg_tower/001-mystic-mage-tower-observatory-at-midnigh.png',
      leftCharacter: '루시안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[루시안] 원문 즉시공개', mainTarget: '루시안', mainDelta: 12, result: '진실이 폭풍처럼 번졌다.'),
        StoryChoice(label: '[세레나] 단계적 공개', mainTarget: '세레나', mainDelta: 12, result: '내전 없이 진실을 퍼뜨렸다.'),
      ],
    ),
    StoryBeat(
      title: '8-2 순혈신화 붕괴',
      speaker: '나레이션',
      line: '왕국의 순혈 신화가 후대 조작으로 밝혀진다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[엘리안] 질서 우선', mainTarget: '엘리안', mainDelta: 11, result: '혼란은 줄었지만 불신은 남았다.'),
        StoryChoice(label: '[세레나] 전면 공개', mainTarget: '세레나', mainDelta: 11, result: '민심은 흔들렸지만 조작은 끝났다.'),
      ],
    ),
    StoryBeat(
      title: '8-3 반동의 파고',
      speaker: '나레이션',
      line: '진실 공개의 반동이 수도를 덮친다.',
      backgroundAsset: 'assets/generated/bg_tower/001-mystic-mage-tower-observatory-at-midnigh.png',
      leftCharacter: '루시안',
      rightCharacter: '엘리안',
      choices: [
        StoryChoice(label: '[루시안] 여론전 개입', mainTarget: '루시안', mainDelta: 12, result: '반동의 파고가 낮아졌다.'),
        StoryChoice(label: '[엘리안] 무력 진압', mainTarget: '엘리안', mainDelta: 8, result: 'BAD_ENDING: 과잉진압으로 정통성은 회복되나 여주의 이상은 붕괴한다.'),
      ],
    ),
    StoryBeat(
      title: '9-1 이중 전선',
      speaker: '나레이션',
      line: '외침과 내란이 동시 발생한다. 전선과 수도를 동시에 운영해야 한다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[엘리안] 전선 우선', mainTarget: '엘리안', mainDelta: 13, result: '국경이 버텼다.'),
        StoryChoice(label: '[세레나] 수도 보급 우선', mainTarget: '세레나', mainDelta: 13, result: '수도가 무너지지 않았다.'),
      ],
    ),
    StoryBeat(
      title: '9-2 은등회 총동원',
      speaker: '세레나',
      line: '여성 네트워크가 의료·보급·정보전의 핵심축으로 부상한다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '세레나',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[세레나] 의료망 확장', mainTarget: '세레나', mainDelta: 12, result: '사망률이 급감했다.'),
        StoryChoice(label: '[루시안] 정보망 확장', mainTarget: '루시안', mainDelta: 12, result: '적의 이동이 먼저 읽혔다.'),
      ],
    ),
    StoryBeat(
      title: '9-3 선언식의 밤',
      speaker: '나레이션',
      line: '결혼식은 동원식이 아닌 새 질서 선언식으로 재설계된다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[엘리안] 군사맹약 중심', mainTarget: '엘리안', mainDelta: 11, result: '전선의 신뢰를 확보했다.'),
        StoryChoice(label: '[세레나] 시민계약 중심', mainTarget: '세레나', mainDelta: 11, result: '도시의 지지를 끌어냈다.'),
      ],
    ),
    StoryBeat(
      title: '10-1 새 규율 초안',
      speaker: '루시안',
      line: '혈통전용 복식법을 폐지하고 직능 기반 시민규율 초안을 공개한다.',
      backgroundAsset: 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      leftCharacter: '루시안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[루시안] 증거재판 병행안', mainTarget: '루시안', mainDelta: 14, result: '법은 의식이 아니라 증거로 움직이기 시작했다.'),
        StoryChoice(label: '[세레나] 합의재판 우선안', mainTarget: '세레나', mainDelta: 14, result: '갈등은 느리지만 덜 피 흘리며 정리됐다.'),
      ],
    ),
    StoryBeat(
      title: '10-2 왕관의 재정의',
      speaker: '나레이션',
      line: '왕관은 혈통 장식이 아니라 책임의 계약으로 재정의된다.',
      backgroundAsset: 'assets/generated/bg_tower/001-mystic-mage-tower-observatory-at-midnigh.png',
      leftCharacter: '엘리안',
      rightCharacter: '루시안',
      choices: [
        StoryChoice(label: '[엘리안] 공동통치 선언', mainTarget: '엘리안', mainDelta: 14, result: '검은 더 이상 왕좌를 위해 들리지 않았다.'),
        StoryChoice(label: '[루시안] 입헌평의 선언', mainTarget: '루시안', mainDelta: 14, result: '권력은 문장으로 분산됐다.'),
      ],
    ),
    StoryBeat(
      title: '10-3 새 규율의 여왕',
      speaker: '나레이션',
      line: '결혼은 해피엔딩이 아니라 공동통치 계약의 시작. 보랏빛 규율의 첫 장이 열린다.',
      backgroundAsset: 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      leftCharacter: '엘리안',
      rightCharacter: '세레나',
      choices: [
        StoryChoice(label: '[메인] 공동통치 계약 서명', mainTarget: '엘리안', mainDelta: 20, result: 'MAIN_HAPPY_ENDING: 은실로 짠 왕관 아래 새 규율의 시대가 시작된다.'),
        StoryChoice(label: '[숨은] 진실 은폐 후 단기안정', mainTarget: '세레나', mainDelta: 8, result: 'BAD_ENDING: 평화는 왔지만 역사는 다시 왜곡된다.'),
      ],
    ),
  ];

  late List<int?> _storySelections;
  Map<int, int> _stepNodePick = {};

  Character _characterByName(String name) => _characters.firstWhere((e) => e.name == name);

  int get _equippedCharm => _outfits.firstWhere((e) => e.id == _equippedOutfitId).charmBonus;
  String get _playerAvatar => _outfits.firstWhere((e) => e.id == _equippedOutfitId).avatarAsset;
  int get _totalCharm => _baseCharm + _equippedCharm;

  String _relationshipLabel(RelationshipState state) {
    switch (state) {
      case RelationshipState.strange:
        return '낯섦';
      case RelationshipState.favorable:
        return '호의';
      case RelationshipState.trust:
        return '신뢰';
      case RelationshipState.shaken:
        return '흔들림';
      case RelationshipState.bond:
        return '유대';
      case RelationshipState.alliedLovers:
        return '동맹연인';
      case RelationshipState.oath:
        return '공동서약';
    }
  }

  RelationshipState _relationshipStateFromCode(String code) {
    switch (code) {
      case 'stranger':
      case 'strange':
        return RelationshipState.strange;
      case 'favorable':
        return RelationshipState.favorable;
      case 'trust':
        return RelationshipState.trust;
      case 'shaken':
        return RelationshipState.shaken;
      case 'bond':
        return RelationshipState.bond;
      case 'allied_lovers':
      case 'alliedLovers':
        return RelationshipState.alliedLovers;
      case 'oath':
        return RelationshipState.oath;
      default:
        return RelationshipState.strange;
    }
  }

  String _characterFlag(String characterName) {
    switch (characterName) {
      case '엘리안':
        return 'publicly_supported_me';
      case '루시안':
        return 'saved_in_ceremony';
      case '세레나':
      default:
        return 'guild_backed';
    }
  }

  String _characterPoliticalStat(String characterName) {
    switch (characterName) {
      case '엘리안':
        return 'military';
      case '루시안':
        return 'legitimacy';
      case '세레나':
      default:
        return 'publicTrust';
    }
  }

  int _affectionThreshold(RelationshipState state) {
    switch (state) {
      case RelationshipState.strange:
        return 35;
      case RelationshipState.favorable:
        return 48;
      case RelationshipState.trust:
        return 62;
      case RelationshipState.shaken:
        return 52;
      case RelationshipState.bond:
        return 76;
      case RelationshipState.alliedLovers:
        return 90;
      case RelationshipState.oath:
        return 101;
    }
  }

  int _politicalThreshold(RelationshipState state) {
    switch (state) {
      case RelationshipState.strange:
        return 28;
      case RelationshipState.favorable:
        return 36;
      case RelationshipState.trust:
        return 44;
      case RelationshipState.shaken:
        return 40;
      case RelationshipState.bond:
        return 54;
      case RelationshipState.alliedLovers:
        return 66;
      case RelationshipState.oath:
        return 999;
    }
  }

  RelationshipState _advanceState(RelationshipState current) {
    switch (current) {
      case RelationshipState.strange:
        return RelationshipState.favorable;
      case RelationshipState.favorable:
        return RelationshipState.trust;
      case RelationshipState.trust:
        return RelationshipState.bond;
      case RelationshipState.shaken:
        return RelationshipState.trust;
      case RelationshipState.bond:
        return RelationshipState.alliedLovers;
      case RelationshipState.alliedLovers:
        return RelationshipState.oath;
      case RelationshipState.oath:
        return RelationshipState.oath;
    }
  }

  void _refreshRelationshipStateFor(Character c, {String source = '관계'}) {
    final current = _relationshipStates[c.name] ?? RelationshipState.strange;
    final statKey = _characterPoliticalStat(c.name);
    final flagKey = _characterFlag(c.name);
    final affectionOk = c.affection >= _affectionThreshold(current);
    final flagOk = _keyFlags[flagKey] ?? false;
    final statOk = (_politicalStats[statKey] ?? 0) >= _politicalThreshold(current);
    RelationshipState next = current;

    if (c.affection < 25 || (_politicalStats['surveillance'] ?? 0) >= 85) {
      next = RelationshipState.shaken;
    } else if (affectionOk && flagOk && statOk) {
      next = _advanceState(current);
    }

    if (next != current) {
      _relationshipStates[c.name] = next;
      _logs.insert(0, '[$source] ${c.name} 관계 상태: ${_relationshipLabel(current)} -> ${_relationshipLabel(next)}');
    }
  }

  void _refreshAllRelationshipStates({String source = '관계'}) {
    for (final c in _characters) {
      _refreshRelationshipStateFor(c, source: source);
    }
  }

  void _applyPoliticalDelta(Map<String, int> delta, String source) {
    delta.forEach((key, value) {
      final next = ((_politicalStats[key] ?? 0) + value).clamp(0, 100);
      _politicalStats[key] = next;
    });
    _logs.insert(0, '[$source] 정치수치 변동: ${delta.entries.map((e) => '${e.key}${e.value >= 0 ? '+' : ''}${e.value}').join(', ')}');
    final s = _politicalStats['surveillance'] ?? 0;
    _surveillanceTimeline.insert(0, s);
    while (_surveillanceTimeline.length > 5) {
      _surveillanceTimeline.removeLast();
    }
  }

  void _applyStoryMetaFlags(StoryChoice choice) {
    if (choice.label.contains('공개') || choice.label.contains('선언')) {
      _keyFlags['publicly_supported_me'] = true;
    }
    if (_storyIndex >= 8) {
      _keyFlags['saved_in_ceremony'] = true;
    }
    if (_storyIndex >= 10) {
      _keyFlags['recipeUnlocked'] = true;
    }
    if (choice.label.contains('희생')) {
      _keyFlags['guild_hostile'] = true;
    }
    if (choice.mainTarget == '세레나') {
      _keyFlags['guild_backed'] = true;
    }
    if (choice.label.contains('증거') || choice.label.contains('감정서')) {
      _evidenceOwned.add('trial_record');
    }
  }

  void _applyStoryPoliticalImpact(StoryChoice choice) {
    final delta = <String, int>{};
    switch (choice.mainTarget) {
      case '엘리안':
        delta['military'] = 6;
        delta['legitimacy'] = 2;
        break;
      case '루시안':
        delta['legitimacy'] = 6;
        delta['economy'] = 2;
        break;
      case '세레나':
        delta['publicTrust'] = 6;
        delta['economy'] = 2;
        break;
    }
    if (choice.label.contains('비밀')) {
      delta['surveillance'] = (delta['surveillance'] ?? 0) + 6;
    }
    if (choice.label.contains('공개') || choice.label.contains('선언')) {
      delta['publicTrust'] = (delta['publicTrust'] ?? 0) + 3;
    }
    _applyPoliticalDelta(delta, '메이저 선택');
  }

  Map<String, dynamic>? _unlockExample(String id) {
    final examples = (_unlockRules['examples'] as List<dynamic>? ?? []);
    for (final item in examples) {
      final map = item as Map<String, dynamic>;
      if (map['id'] == id) return map;
    }
    return null;
  }

  Character? _characterFromUnlockTarget(String raw) {
    if (raw == 'knight') return _characterByName('엘리안');
    if (raw == 'rival') return _characterByName('세레나');
    if (raw == 'mage') return _characterByName('루시안');
    for (final c in _characters) {
      if (c.name == raw) return c;
    }
    return null;
  }

  bool _evaluateCondition(Map<String, dynamic> condition) {
    final type = condition['type']?.toString() ?? '';
    switch (type) {
      case 'affectionThreshold':
        final targetRaw = condition['target']?.toString() ?? '';
        final target = _characterFromUnlockTarget(targetRaw);
        if (target == null) return false;
        return target.affection >= (condition['value'] as int? ?? 0);
      case 'stateReached':
        final targetRaw = condition['target']?.toString() ?? '';
        final target = _characterFromUnlockTarget(targetRaw);
        if (target == null) return false;
        final required = _relationshipStateFromCode(condition['value']?.toString() ?? 'strange');
        final current = _relationshipStates[target.name] ?? RelationshipState.strange;
        return current.index >= required.index;
      case 'politicalStatThreshold':
        final stat = condition['stat']?.toString() ?? '';
        final threshold = condition['value'] as int? ?? 0;
        return (_politicalStats[stat] ?? 0) >= threshold;
      case 'flagTrue':
        final flag = condition['flag']?.toString() ?? '';
        return _keyFlags[flag] ?? false;
      case 'evidenceOwned':
        final key = condition['id']?.toString() ?? '';
        return _evidenceOwned.contains(key);
      case 'costumeTag':
        final tag = condition['tag']?.toString() ?? '';
        return _costumeTags.contains(tag);
      default:
        return false;
    }
  }

  UnlockDecision _evaluateUnlockRule(String exampleId) {
    final example = _unlockExample(exampleId);
    if (example == null) return const UnlockDecision(unlocked: true, reason: '');
    final conditions = (example['conditions'] as List<dynamic>).cast<Map<String, dynamic>>();
    final passes = conditions.where(_evaluateCondition).length;
    final ruleText = example['rule']?.toString() ?? '';
    final split = ruleText.split('of');
    int required = conditions.length;
    if (split.length == 2) {
      required = int.tryParse(split.first) ?? required;
    }
    final unlocked = passes >= required;
    if (unlocked) {
      return const UnlockDecision(unlocked: true, reason: '');
    }
    return UnlockDecision(
      unlocked: false,
      reason: '잠금 조건 미달성 ($passes/$required). 호감도·정치수치·핵심 플래그를 확인하세요.',
    );
  }

  UnlockDecision _evaluateTemplateRule(String templateName, List<Map<String, dynamic>> conditions) {
    final templates = (_unlockRules['unlockTemplates'] as Map<String, dynamic>? ?? {});
    final template = (templates[templateName] as Map<String, dynamic>? ?? {});
    final pool = (template['pool'] as List<dynamic>? ?? []).map((e) => e.toString()).toSet();
    final scoped = conditions.where((c) => pool.contains(c['type']?.toString() ?? '')).toList();
    final passes = scoped.where(_evaluateCondition).length;
    final requiredAll = template['requiredAll'] as int?;
    final requiredAny = template['requiredAny'] as int?;
    final required = requiredAll ?? requiredAny ?? scoped.length;
    if (passes >= required) {
      return const UnlockDecision(unlocked: true, reason: '');
    }
    return UnlockDecision(unlocked: false, reason: '템플릿($templateName) 조건 미충족: $passes/$required');
  }

  void _lockRouteAtNode15IfNeeded() {
    if (_storyIndex != 14 || _lockedRouteCharacterName != null) return;
    Character top = _characters.first;
    for (final c in _characters.skip(1)) {
      if (c.affection > top.affection) top = c;
    }
    _lockedRouteCharacterName = top.name;
    _logs.insert(0, '[루트] 15노드에서 ${top.name} 루트가 잠금 확정되었습니다.');
  }

  bool _isChoiceBlockedByRouteLock(StoryChoice choice) {
    return _lockedRouteCharacterName != null && _storyIndex >= 14 && choice.mainTarget != _lockedRouteCharacterName;
  }

  bool _matchesEndingRequirement(String key, dynamic value) {
    if (key == 'recipeUnlocked') {
      return (_keyFlags['recipeUnlocked'] ?? false) == value;
    }
    if (key == 'surveillanceMax') {
      return (_politicalStats['surveillance'] ?? 0) <= (value as int? ?? 100);
    }
    return (_politicalStats[key] ?? 0) >= (value as int? ?? 0);
  }

  bool _matchesEndingTrigger(String trigger) {
    switch (trigger) {
      case 'node10_total_below_80':
        final total = (_politicalStats['legitimacy'] ?? 0) + (_politicalStats['economy'] ?? 0) + (_politicalStats['publicTrust'] ?? 0) + (_politicalStats['military'] ?? 0);
        return total < 80;
      case 'surveillance_100':
        return (_politicalStats['surveillance'] ?? 0) >= 100;
      case 'guild_hostile_and_military_low':
        return (_keyFlags['guild_hostile'] ?? false) && (_politicalStats['military'] ?? 0) < 45;
      default:
        return false;
    }
  }

  EndingDecision? _evaluateEndingDecision() {
    final endings = (_endingRules['endings'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final priority = (_endingRules['priority'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    for (final id in priority) {
      Map<String, dynamic>? ending;
      for (final e in endings) {
        if (e['id'] == id) {
          ending = e;
          break;
        }
      }
      if (ending == null) continue;
      final requires = (ending['requires'] as Map<String, dynamic>? ?? {});
      final trigger = ending['trigger']?.toString();
      bool matched = true;
      if (requires.isNotEmpty) {
        for (final entry in requires.entries) {
          if (!_matchesEndingRequirement(entry.key, entry.value)) {
            matched = false;
            break;
          }
        }
      }
      if (trigger != null && !_matchesEndingTrigger(trigger)) {
        matched = false;
      }
      if (matched) {
        return EndingDecision(id: id, type: ending['type']?.toString() ?? '미정');
      }
    }
    return const EndingDecision(id: 'fallback_bad', type: '배드');
  }

  @override
  void initState() {
    super.initState();
    _storySelections = List<int?>.filled(_story.length, null);
    for (final c in _characters) {
      _expressions[c.name] = Expression.neutral;
      _relationshipStates[c.name] = RelationshipState.strange;
    }
    _bootstrap();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _workTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadRuleFiles();
    await _load();
  }

  Future<void> _loadRuleFiles() async {
    try {
      _unlockRules = jsonDecode(await rootBundle.loadString('unlock_rules_v3.json')) as Map<String, dynamic>;
    } catch (_) {}
    try {
      _endingRules = jsonDecode(await rootBundle.loadString('ending_rules.json')) as Map<String, dynamic>;
    } catch (_) {}
    try {
      _statBalanceTable = jsonDecode(await rootBundle.loadString('stat_balance_table.json')) as Map<String, dynamic>;
    } catch (_) {}
    try {
      _premiumCatalog = jsonDecode(await rootBundle.loadString('premium_choices_v1.json')) as Map<String, dynamic>;
    } catch (_) {}
    try {
      _unlockContentSchema = jsonDecode(await rootBundle.loadString('unlock_content_schema_v1.json')) as Map<String, dynamic>;
    } catch (_) {}
    void mergeNodesFromJson(Map<String, dynamic> m, Map<int, List<Map<String, dynamic>>> targetDialogues,
        Map<int, List<Map<String, dynamic>>> targetCheckpoints) {
      final nodes = (m['nodes'] as List<dynamic>? ?? []);
      for (final n in nodes) {
        final map = n as Map<String, dynamic>;
        final id = map['node'] as int?;
        if (id == null) continue;
        final lines = (map['lines'] as List<dynamic>? ?? []).map((e) {
          final l = e as Map<String, dynamic>;
          return {
            'speaker': l['speaker']?.toString() ?? '나',
            'line': l['line']?.toString() ?? '',
            'cond': l['cond'],
          };
        }).toList();
        targetDialogues[id] = lines;

        final cps = (map['checkpoints'] as List<dynamic>? ?? []).map((e) => (e as Map<String, dynamic>)).toList();
        targetCheckpoints[id] = cps;
      }
    }

    try {
      _nodeDialogues.clear();
      _nodeCheckpoints.clear();
      for (final r in _routeNodeDialogues.keys) {
        _routeNodeDialogues[r]!.clear();
        _routeNodeCheckpoints[r]!.clear();
      }

      final base = jsonDecode(await rootBundle.loadString('story_dialogues_30.json')) as Map<String, dynamic>;
      mergeNodesFromJson(base, _nodeDialogues, _nodeCheckpoints);

      try {
        final cine = jsonDecode(await rootBundle.loadString('story_dialogues_cinematic_1_30.json')) as Map<String, dynamic>;
        mergeNodesFromJson(cine, _nodeDialogues, _nodeCheckpoints);
      } catch (_) {
        try {
          final cineLegacy = jsonDecode(await rootBundle.loadString('story_dialogues_cinematic_1_10.json')) as Map<String, dynamic>;
          mergeNodesFromJson(cineLegacy, _nodeDialogues, _nodeCheckpoints);
        } catch (_) {}
      }

      try {
        final e = jsonDecode(await rootBundle.loadString('story_dialogues_route_elian_1_30.json')) as Map<String, dynamic>;
        mergeNodesFromJson(e, _routeNodeDialogues['elian']!, _routeNodeCheckpoints['elian']!);
      } catch (_) {
        try {
          final eLegacy = jsonDecode(await rootBundle.loadString('story_dialogues_route_elian_16_30.json')) as Map<String, dynamic>;
          mergeNodesFromJson(eLegacy, _routeNodeDialogues['elian']!, _routeNodeCheckpoints['elian']!);
        } catch (_) {}
      }
      try {
        final l = jsonDecode(await rootBundle.loadString('story_dialogues_route_lucian_1_30.json')) as Map<String, dynamic>;
        mergeNodesFromJson(l, _routeNodeDialogues['lucian']!, _routeNodeCheckpoints['lucian']!);
      } catch (_) {
        try {
          final lLegacy = jsonDecode(await rootBundle.loadString('story_dialogues_route_lucian_16_30.json')) as Map<String, dynamic>;
          mergeNodesFromJson(lLegacy, _routeNodeDialogues['lucian']!, _routeNodeCheckpoints['lucian']!);
        } catch (_) {}
      }
      try {
        final s = jsonDecode(await rootBundle.loadString('story_dialogues_route_serena_1_30.json')) as Map<String, dynamic>;
        mergeNodesFromJson(s, _routeNodeDialogues['serena']!, _routeNodeCheckpoints['serena']!);
      } catch (_) {
        try {
          final sLegacy = jsonDecode(await rootBundle.loadString('story_dialogues_route_serena_16_30.json')) as Map<String, dynamic>;
          mergeNodesFromJson(sLegacy, _routeNodeDialogues['serena']!, _routeNodeCheckpoints['serena']!);
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    final pref = await SharedPreferences.getInstance();
    final raw = pref.getString(_saveKey);
    if (raw != null) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _gold = m['gold'] ?? _gold;
      _premiumTokens = m['premiumTokens'] ?? _premiumTokens;
      _storyIndex = (m['storyIndex'] ?? _storyIndex) as int;
      if (_storyIndex < 0) _storyIndex = 0;
      if (_storyIndex >= _story.length) _storyIndex = _story.length - 1;
      _baseCharm = m['baseCharm'] ?? _baseCharm;
      _equippedOutfitId = m['equippedOutfitId'] ?? _equippedOutfitId;
      _endingCharacterName = m['endingCharacterName'] as String?;
      _lockedRouteCharacterName = m['lockedRouteCharacterName'] as String?;
      _endingRuleId = m['endingRuleId'] as String?;
      _endingRuleType = m['endingRuleType'] as String?;
      _endingEvaluated = m['endingEvaluated'] ?? _endingEvaluated;
      final loadedSelections = ((m['storySelections'] as List<dynamic>?) ?? const [])
          .map<int?>((e) => e == null ? null : e as int)
          .toList();
      _storySelections = List<int?>.filled(_story.length, null);
      for (int i = 0; i < loadedSelections.length && i < _storySelections.length; i++) {
        _storySelections[i] = loadedSelections[i];
      }

      final stepPickRaw = (m['stepNodePick'] as Map<String, dynamic>? ?? {});
      _stepNodePick = stepPickRaw.map((k, v) => MapEntry(int.parse(k), v as int));
      _logs
        ..clear()
        ..addAll((m['logs'] as List<dynamic>? ?? []).map((e) => e.toString()));

      final charRaw = (m['characters'] as List<dynamic>? ?? []);
      if (charRaw.length == _characters.length) {
        for (int i = 0; i < _characters.length; i++) {
          _characters[i].affection = (charRaw[i]['affection'] ?? _characters[i].affection) as int;
        }
      }

      final relationRaw = (m['relationshipStates'] as Map<String, dynamic>? ?? {});
      for (final c in _characters) {
        _relationshipStates[c.name] = _relationshipStateFromCode(relationRaw[c.name]?.toString() ?? 'strange');
      }

      final politicalRaw = (m['politicalStats'] as Map<String, dynamic>? ?? {});
      for (final key in _politicalStats.keys) {
        _politicalStats[key] = (politicalRaw[key] ?? _politicalStats[key]) as int;
      }

      final flagRaw = (m['keyFlags'] as Map<String, dynamic>? ?? {});
      for (final key in _keyFlags.keys) {
        _keyFlags[key] = (flagRaw[key] ?? _keyFlags[key]) as bool;
      }

      _evidenceOwned
        ..clear()
        ..addAll((m['evidenceOwned'] as List<dynamic>? ?? []).map((e) => e.toString()));
      _costumeTags
        ..clear()
        ..addAll((m['costumeTags'] as List<dynamic>? ?? []).map((e) => e.toString()));
      final adRaw = (m['dailyAdViews'] as Map<String, dynamic>? ?? {});
      _dailyAdViews
        ..clear()
        ..addAll(adRaw.map((k, v) => MapEntry(k, v as int)));
      final surRaw = (m['surveillanceTimeline'] as List<dynamic>? ?? const []);
      if (surRaw.isNotEmpty) {
        _surveillanceTimeline
          ..clear()
          ..addAll(surRaw.map((e) => e as int));
      }
    }

    _lockRouteAtNode15IfNeeded();
    _nodeDialogueIndex = 0;
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
        'premiumTokens': _premiumTokens,
        'storyIndex': _storyIndex,
        'baseCharm': _baseCharm,
        'equippedOutfitId': _equippedOutfitId,
        'endingCharacterName': _endingCharacterName,
        'lockedRouteCharacterName': _lockedRouteCharacterName,
        'endingRuleId': _endingRuleId,
        'endingRuleType': _endingRuleType,
        'endingEvaluated': _endingEvaluated,
        'storySelections': _storySelections,
        'stepNodePick': _stepNodePick.map((k, v) => MapEntry(k.toString(), v)),
        'logs': _logs,
        'characters': _characters.map((e) => e.toJson()).toList(),
        'relationshipStates': _relationshipStates.map((k, v) => MapEntry(k, v.name)),
        'politicalStats': _politicalStats,
        'keyFlags': _keyFlags,
        'evidenceOwned': _evidenceOwned.toList(),
        'costumeTags': _costumeTags.toList(),
        'dailyAdViews': _dailyAdViews,
        'surveillanceTimeline': _surveillanceTimeline,
      }),
    );
  }

  void _playClick() => SystemSound.play(SystemSoundType.click);
  void _playReward() => SystemSound.play(SystemSoundType.alert);

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  int _adViewCount(String placement) => _dailyAdViews['${_todayKey}_$placement'] ?? 0;

  Future<bool> _consumeAdView(String placement, int limitPerDay) async {
    final key = '${_todayKey}_$placement';
    final current = _dailyAdViews[key] ?? 0;
    if (current >= limitPerDay) return false;
    _dailyAdViews[key] = current + 1;
    await _save();
    return true;
  }

  int _scaledGain(int base) => base + (_totalCharm ~/ 5);

  void _setExpression(String name, Expression expression) {
    _expressions[name] = expression;
  }

  bool _lineCondOk(dynamic condRaw) {
    if (condRaw == null) return true;
    if (condRaw is! Map<String, dynamic>) return true;

    final partner = condRaw['partner_lock']?.toString();
    if (partner != null) {
      final locked = _lockedRouteCharacterName;
      final code = locked == '엘리안' ? 'elian' : locked == '루시안' ? 'lucian' : locked == '세레나' ? 'serena' : null;
      if (code != partner) return false;
    }

    final flag = condRaw['flag']?.toString();
    if (flag != null && !(_keyFlags[flag] ?? false)) return false;

    final stat = condRaw['stat']?.toString();
    if (stat != null) {
      final minV = (condRaw['min'] as num?)?.toInt() ?? 0;
      if ((_politicalStats[stat] ?? 0) < minV) return false;
    }

    return true;
  }

  String? _lockedRouteCode() {
    if (_lockedRouteCharacterName == '엘리안') return 'elian';
    if (_lockedRouteCharacterName == '루시안') return 'lucian';
    if (_lockedRouteCharacterName == '세레나') return 'serena';
    return null;
  }

  List<Map<String, dynamic>> _activeNodeLines(int nodeId) {
    final route = _lockedRouteCode();
    if (route != null) {
      final routeLines = _routeNodeDialogues[route]?[nodeId];
      if (routeLines != null && routeLines.isNotEmpty) return routeLines;
    }
    return _nodeDialogues[nodeId] ?? const [];
  }

  List<Map<String, dynamic>> _currentDialogueLines() {
    final raw = _activeNodeLines(_storyIndex + 1);
    if (raw.isEmpty) {
      final b = _story[_storyIndex];
      return [
        {'speaker': b.speaker, 'line': b.line}
      ];
    }
    final filtered = raw.where((e) => _lineCondOk(e['cond'])).toList();
    if (filtered.isEmpty) return raw;
    return filtered;
  }

  String _currentSpeaker() {
    final lines = _currentDialogueLines();
    final i = _nodeDialogueIndex.clamp(0, lines.length - 1);
    return lines[i]['speaker'] ?? _story[_storyIndex].speaker;
  }

  String _sceneBackgroundAssetForNode(int index) {
    const pack = [
      'assets/generated/bg_storypack/bg_corridor.png',
      'assets/generated/bg_storypack/bg_archive.png',
      'assets/generated/bg_storypack/bg_courtyard_rain.png',
      'assets/generated/bg_storypack/bg_ledger_room.png',
      'assets/generated/bg_storypack/bg_infirmary_dawn.png',
      'assets/generated/bg_storypack/bg_tribunal_hall.png',
    ];
    return pack[index % pack.length];
  }

  bool _hasNextDialogueLine() {
    final lines = _currentDialogueLines();
    return _nodeDialogueIndex < lines.length - 1;
  }

  List<Map<String, dynamic>> _activeNodeCheckpoints(int nodeId) {
    final route = _lockedRouteCode();
    if (route != null) {
      final routeCps = _routeNodeCheckpoints[route]?[nodeId];
      if (routeCps != null && routeCps.isNotEmpty) return routeCps;
    }
    return _nodeCheckpoints[nodeId] ?? const [];
  }

  Map<String, dynamic>? _currentCheckpoint() {
    final cps = _activeNodeCheckpoints(_storyIndex + 1);
    final resolved = _resolvedCheckpointAts[_storyIndex + 1] ?? <int>{};
    for (final cp in cps) {
      final at = cp['at'] as int? ?? -1;
      if (at == _nodeDialogueIndex && !resolved.contains(at)) return cp;
    }
    return null;
  }

  bool _isCheckpointPending() => _currentCheckpoint() != null;

  Future<void> _applyCheckpointChoice(Map<String, dynamic> option) async {
    final targetName = option['target']?.toString();
    final delta = option['affectionDelta'] as int? ?? 0;
    final polit = (option['political'] as Map<String, dynamic>? ?? {});
    final text = option['result']?.toString() ?? '선택 결과가 반영되었다.';

    if (targetName != null && targetName.isNotEmpty && delta != 0) {
      final c = _characterByName(targetName);
      await _addAffection(c, delta, '[체크포인트]');
    }

    if (polit.isNotEmpty) {
      final m = <String, int>{};
      for (final e in polit.entries) {
        m[e.key] = (e.value as num).toInt();
      }
      _applyPoliticalDelta(m, '체크포인트');
    }

    final at = (_currentCheckpoint()?['at'] as int? ?? _nodeDialogueIndex);
    _resolvedCheckpointAts.putIfAbsent(_storyIndex + 1, () => <int>{}).add(at);
    _logs.insert(0, '[체크포인트] $text');

    if (_hasNextDialogueLine()) {
      setState(() => _nodeDialogueIndex += 1);
      _beginBeatLine();
    }
    await _save();
  }

  void _nextDialogueLine() {
    if (!_hasNextDialogueLine()) return;
    setState(() {
      _nodeDialogueIndex += 1;
    });
    _beginBeatLine();
  }

  Future<void> _openCheckpointPopup(StoryBeat beat) async {
    final cp = _currentCheckpoint();
    if (cp == null || !mounted) return;
    final title = cp['title']?.toString() ?? '중간 선택';
    final options = (cp['options'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('체크포인트 선택을 완료해야 다음 대사로 진행됩니다.'),
                const SizedBox(height: 10),
                ...options.map((o) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _applyCheckpointChoice(o);
                        },
                        child: Text(o['label']?.toString() ?? '선택'),
                      ),
                    )),
                const SizedBox(height: 8),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('추가 옵션 펼치기 (광고/프리미엄)'),
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            Navigator.pop(context);
                            await _watchRewardAdSkeleton();
                          },
                          icon: const Icon(Icons.ondemand_video),
                          label: const Text('보상 광고(+1 토큰)'),
                        ),
                        FilledButton.icon(
                          onPressed: _endingCharacterName == null
                              ? () {
                                  Navigator.pop(context);
                                  Future.microtask(() => _openPremiumChoiceFlow(beat));
                                }
                              : null,
                          icon: const Icon(Icons.stars),
                          label: Text('프리미엄 선택지 (보유: $_premiumTokens)'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
      ),
    );
  }

  void _beginBeatLine() {
    _typingTimer?.cancel();
    final lines = _currentDialogueLines();
    final idx = _nodeDialogueIndex.clamp(0, lines.length - 1);
    final line = lines[idx]['line'] ?? _story[_storyIndex].line;
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
    final ms = _autoPlay ? 18 : 34;
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
    _refreshRelationshipStateFor(target, source: logPrefix.replaceAll('[', '').replaceAll(']', ''));
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
    if (_isChoiceBlockedByRouteLock(choice)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('루트 잠금: $_lockedRouteCharacterName 진행 중입니다.')));
      return;
    }
    _playClick();
    final pickedNodeIndex = _storyIndex;

    _storySelections[_storyIndex] = choiceIndex;
    _applyStoryMetaFlags(choice);
    _applyStoryPoliticalImpact(choice);

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
      _nodeDialogueIndex = 0;
      _sceneKey += 1;
      _cameraSeed = '${_random.nextDouble()}';
      _transitionPreset = choice.sideDelta < 0 ? TransitionPreset.flash : TransitionPreset.slide;
    }

    _lockRouteAtNode15IfNeeded();
    await _evaluateEndingIfNeeded(pickedNodeIndex, choice.result);
    await _maybeShowCrisisRescue();
    _refreshAllRelationshipStates(source: '메이저 선택');

    _beginBeatLine();
    await _save();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('결과'),
        content: Text('${choice.result}\n\n획득: 금화 +${10 + (_totalCharm ~/ 2)} / 민심 +1'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('다음 노드로')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final ok = await _consumeAdView('after_node_clear_bonus', 10);
              if (!ok || !mounted) return;
              _gold += 80;
              _logs.insert(0, '[광고 보상] 노드 클리어 추가 보상 수령');
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('30초 시청 보상: 금화+80 / 실크+1')));
              setState(() {});
            },
            child: const Text('보상 추가 받기(광고)'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _watchRewardAdSkeleton(placement: 'premium_token_daily');
            },
            child: const Text('프리미엄 토큰 받기(광고)'),
          ),
        ],
      ),
    );
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
    _applyPoliticalDelta({_characterPoliticalStat(target.name): 2, 'publicTrust': 1}, '상점 선물');
    _setExpression(target.name, Expression.blush);
    _refreshRelationshipStateFor(target, source: '상점');
    await _save();
    setState(() {});
  }

  void _showQuickInventory() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/mini_inventory_sheet.png'), fit: BoxFit.cover)),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('빠른 장착', style: TextStyle(fontWeight: FontWeight.w700)),
            ..._outfits.map((o) => ListTile(
                  title: Text(o.name),
                  subtitle: Text('매력 +${o.charmBonus}'),
                  trailing: o.id == _equippedOutfitId ? const Text('착용중') : null,
                  onTap: () {
                    setState(() => _equippedOutfitId = o.id);
                    _save();
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _buyOutfit(OutfitItem item) async {
    if (_gold < item.price) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('골드가 부족합니다.')));
      return;
    }
    _playClick();
    _gold -= item.price;
    _equippedOutfitId = item.id;
    if (item.id.contains('noble')) _costumeTags.add('noble');
    if (item.id.contains('ranger')) _costumeTags.add('ranger');
    if (item.id.contains('moon')) _costumeTags.add('moon');
    _logs.insert(0, '[장착] ${item.name} 착용 (매력 +${item.charmBonus})');
    await _save();
    setState(() {});
  }

  String _pKey(int x, int y) => '$x:$y';

  FlameMode _toFlameMode(WorkMiniGame game) {
    switch (game) {
      case WorkMiniGame.herbSort:
        return FlameMode.herb;
      case WorkMiniGame.smithTiming:
        return FlameMode.smith;
      case WorkMiniGame.haggling:
        return FlameMode.haggling;
      case WorkMiniGame.courierRun:
        return FlameMode.courier;
      case WorkMiniGame.dateDance:
        return FlameMode.dance;
      case WorkMiniGame.gardenWalk:
        return FlameMode.garden;
    }
  }

  void _startFlameGame() {
    void safeSet(VoidCallback fn) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(fn);
      });
    }

    setState(() {
      _workTimeLeft = 20;
      _workScore = 0;
      _combo = 0;
    });

    final game = DotFlameGame(
      mode: _toFlameMode(_selectedWork),
      durationSec: 20,
      onTick: (s) => safeSet(() => _workTimeLeft = s),
      onScore: (s) => safeSet(() => _workScore = s),
      onCombo: (c) => safeSet(() => _combo = c),
      onFail: _flashFail,
      onDone: (score, combo) async {
        if (!mounted) return;
        _workScore = score;
        _combo = combo;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        await _finishWorkMiniGame();
      },
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: GameWidget(game: game)),
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.55), borderRadius: BorderRadius.circular(8)),
                  child: Text('⏱ $_workTimeLeft  점수 $_workScore  콤보 x$_combo', style: const TextStyle(color: Colors.white)),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _prepareWorkRound() {
    switch (_selectedWork) {
      case WorkMiniGame.herbSort:
        const herbs = ['라벤더', '로즈마리', '박하', '세이지'];
        _herbTarget = herbs[_random.nextInt(herbs.length)];
        _herbPos = const Point(3, 3);
        _herbGrid = List.generate(7, (_) => List.filled(7, 0));
        for (int y = 0; y < 7; y++) {
          for (int x = 0; x < 7; x++) {
            final r = _random.nextInt(100);
            if (r < 12) _herbGrid[y][x] = 1; // herb
            if (r >= 12 && r < 18) _herbGrid[y][x] = 2; // poison
            if (r >= 18 && r < 21) _herbGrid[y][x] = 3; // rare
            if (r >= 21 && r < 28) _herbGrid[y][x] = 4; // rock
          }
        }
        _herbGrid[3][3] = 0;
        break;
      case WorkMiniGame.smithTiming:
        _smithMeter = _random.nextDouble();
        _smithDirForward = _random.nextBool();
        break;
      case WorkMiniGame.haggling:
        _hagglingTarget = 35 + _random.nextInt(31).toDouble();
        _hagglingOffer = 20 + _random.nextInt(61).toDouble();
        _marketCursor = _random.nextDouble();
        _marketDirForward = _random.nextBool();
        break;
      case WorkMiniGame.courierRun:
        _courierPos = const Point(0, 3);
        _courierDocs = {'6:1', '6:3', '6:5'};
        break;
      case WorkMiniGame.dateDance:
        _danceNeed = _random.nextInt(4);
        _danceStreak = 0;
        break;
      case WorkMiniGame.gardenWalk:
        _gardenPos = const Point(3, 3);
        _gardenHearts = {'1:1', '5:2', '2:5', '6:6'};
        _gardenThorns = {'4:1', '1:4', '5:5'};
        break;
    }
  }

  void _startWorkMiniGame() {
    _playClick();
    _workTimer?.cancel();
    _workTimeLeft = 20;
    _workScore = 0;
    _combo = 0;
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

      if (_selectedWork == WorkMiniGame.haggling) {
        final d = 0.04;
        if (_marketDirForward) {
          _marketCursor += d;
          if (_marketCursor >= 1) {
            _marketCursor = 1;
            _marketDirForward = false;
          }
        } else {
          _marketCursor -= d;
          if (_marketCursor <= 0) {
            _marketCursor = 0;
            _marketDirForward = true;
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
      _animTick += 1;
      if (_cutinTicks > 0) {
        _cutinTicks -= 1;
        if (_cutinTicks == 0) _cutinCharacter = null;
      }
      setState(() {});
    });

    setState(() {});
  }

  Future<void> _finishWorkMiniGame() async {
    if (!mounted) return;
    final reward = 30 + (_workScore * 9);
    _gold += reward;
    _logs.insert(0, '[미니게임:${_selectedWork.name}] 점수 $_workScore, 콤보 $_combo, 골드 +$reward');
    if (_selectedWork == WorkMiniGame.dateDance || _selectedWork == WorkMiniGame.gardenWalk) {
      final c = _characters[_random.nextInt(_characters.length)];
      c.affection = (c.affection + 1).clamp(0, 100);
      _logs.insert(0, '[감정선] ${c.name} 호감 +1 (미니게임 연동)');
    }
    _playReward();
    await _save();
    if (_menuIndex == 3 && mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('미니게임 결과'),
          content: Text('점수: $_workScore\n보상: 금화 $reward / 재료 2개'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('돌아가기')),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final ok = await _consumeAdView('after_minigame_double', 8);
                if (!ok || !mounted) return;
                _gold += reward;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('광고 보상: 미니게임 보상 2배 적용')));
                setState(() {});
              },
              child: const Text('보상 2배(광고)'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final ok = await _consumeAdView('after_minigame_extra', 5);
                if (!ok || !mounted) return;
                _workTimeLeft = 0;
                _startWorkMiniGame();
              },
              child: const Text('추가 알바 1회(광고)'),
            ),
          ],
        ),
      );
      setState(() {});
    }
  }

  void _flashFail() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _failFlash = true);
      Future.delayed(const Duration(milliseconds: 140), () {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback((__) {
          if (!mounted) return;
          setState(() => _failFlash = false);
        });
      });
    });
  }

  void _triggerCutInForWork() {
    const lines = {
      '엘리안': ['좋아, 계속 가자!', '완벽한 타이밍이다.', '네 손끝이 전장을 바꾼다.', '멈추지 마, 지금 흐름 좋다.', '훌륭해. 다음도 그렇게.'],
      '루시안': ['좋아, 계속 가자!', '방금 선택, 아주 정확했어.', '흐름이 우리 편이야.', '계산보다 감각이 빨라.', '지금 리듬을 유지해.'],
      '세레나': ['좋아, 계속 가자!', '협상은 지금부터가 진짜야.', '아름답게 압도해 줘.', '좋아, 상대가 흔들리고 있어.', '한 수 위라는 걸 보여줘.'],
    };

    switch (_selectedWork) {
      case WorkMiniGame.smithTiming:
        _cutinCharacter = '엘리안';
        break;
      case WorkMiniGame.haggling:
        _cutinCharacter = '세레나';
        break;
      case WorkMiniGame.herbSort:
      case WorkMiniGame.gardenWalk:
      case WorkMiniGame.dateDance:
      case WorkMiniGame.courierRun:
        _cutinCharacter = '루시안';
        break;
    }

    final pool = lines[_cutinCharacter!]!;
    _cutinLine = pool[_random.nextInt(pool.length)];
    _cutinTicks = 12;
  }

  String _cutinSheet(String name) {
    if (name == '엘리안') return 'assets/ui/dot_elian_sheet.png';
    if (name == '세레나') return 'assets/ui/dot_serena_sheet.png';
    return 'assets/ui/dot_lucian_sheet.png';
  }

  void _gainCombo(int scoreGain) {
    _combo += 1;
    _workScore += scoreGain + (_combo ~/ 3);
    if (_combo > 0 && _combo % 3 == 0) {
      _triggerCutInForWork();
    }
  }

  void _resetCombo() {
    _combo = 0;
  }

  void _workMove(int dx, int dy) {
    if (_workTimeLeft <= 0) return;
    if (_selectedWork == WorkMiniGame.herbSort) {
      final nx = (_herbPos.x + dx).clamp(0, 6);
      final ny = (_herbPos.y + dy).clamp(0, 6);
      if (_herbGrid[ny][nx] == 4) return;
      _herbPos = Point(nx, ny);
      final cell = _herbGrid[ny][nx];
      if (cell == 1) {
        _gainCombo(2);
        _herbGrid[ny][nx] = 0;
      } else if (cell == 2) {
        _workScore = max(0, _workScore - 2);
        _resetCombo();
        _flashFail();
      } else if (cell == 3) {
        _gainCombo(4);
        _applyPoliticalDelta({'publicTrust': 1}, '희귀 약초');
        _herbGrid[ny][nx] = 0;
      }
    } else if (_selectedWork == WorkMiniGame.courierRun) {
      final nx = (_courierPos.x + dx).clamp(0, 6);
      final ny = (_courierPos.y + dy).clamp(0, 6);
      _courierPos = Point(nx, ny);
      final key = _pKey(nx, ny);
      if (_courierDocs.contains(key)) {
        _courierDocs.remove(key);
        _gainCombo(3);
      }
      for (final g in _guards) {
        if ((g.y - ny).abs() <= 0 && nx > g.x && nx - g.x <= 2) {
          _workScore = max(0, _workScore - 2);
          _resetCombo();
          _flashFail();
          _applyPoliticalDelta({'surveillance': 1}, '경비 시야 노출');
          break;
        }
      }
    } else if (_selectedWork == WorkMiniGame.gardenWalk) {
      final nx = (_gardenPos.x + dx).clamp(0, 6);
      final ny = (_gardenPos.y + dy).clamp(0, 6);
      _gardenPos = Point(nx, ny);
      final key = _pKey(nx, ny);
      if (_gardenHearts.contains(key)) {
        _gardenHearts.remove(key);
        _gainCombo(2);
      }
      if (_gardenThorns.contains(key)) {
        _workScore = max(0, _workScore - 1);
        _resetCombo();
        _flashFail();
      }
    }
    setState(() {});
  }

  void _workActionHerb(String herb) {
    // legacy: mapped to movement mode
    _workMove(1, 0);
  }

  void _workActionSmith() {
    if (_workTimeLeft <= 0) return;
    final dist = (_smithMeter - 0.5).abs();
    if (dist < 0.06) {
      _gainCombo(4);
      if (_combo >= 3) {
        _logs.insert(0, '[보이스] 엘리안: 대단하군.');
      }
    } else if (dist < 0.14) {
      _gainCombo(2);
    } else {
      _workScore = max(0, _workScore - 1);
      _resetCombo();
      _flashFail();
    }
    _playClick();
    setState(() {});
  }

  void _workActionHaggling() {
    if (_workTimeLeft <= 0) return;
    final offer = 20 + (_marketCursor * 60);
    final diff = (offer - _hagglingTarget).abs();
    if (diff <= 2) {
      _gainCombo(4);
      _playReward();
    } else if (diff <= 6) {
      _gainCombo(2);
      _playClick();
    } else {
      _workScore = max(0, _workScore - 1);
      _resetCombo();
      _flashFail();
    }
    setState(() {});
  }

  void _workActionDance(int input) {
    if (_workTimeLeft <= 0) return;
    if (input == _danceNeed) {
      _danceStreak += 1;
      _gainCombo(3);
      if (_danceStreak % 3 == 0) {
        _logs.insert(0, '[로맨스] 손잡기 연출 성공');
      }
    } else {
      _danceStreak = 0;
      _resetCombo();
      _workScore = max(0, _workScore - 1);
      _flashFail();
    }
    _danceNeed = _random.nextInt(4);
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
    _applyPoliticalDelta({_characterPoliticalStat(target.name): 3, 'publicTrust': 1}, '데이트');
    _keyFlags['saved_in_ceremony'] = true;
    _setExpression(target.name, Expression.blush);
    _logs.insert(0, '[상황] $picked');
    _refreshRelationshipStateFor(target, source: '데이트');
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

  List<Map<String, dynamic>> _premiumSamplesForNode(int nodeNumber) {
    final all = (_premiumCatalog['premiumChoices'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return all.where((e) => (e['node'] as int? ?? -1) == nodeNumber).toList();
  }

  Map<String, dynamic>? _premiumSampleForChoice(int nodeNumber, StoryChoice choice, {int choiceIndex = 0}) {
    final samples = _premiumSamplesForNode(nodeNumber);
    if (samples.isEmpty) return null;
    for (final s in samples) {
      if (s['targetName']?.toString() == choice.mainTarget) return s;
    }
    return choiceIndex < samples.length ? samples[choiceIndex] : samples.first;
  }

  String _choiceKindLabel(ChoiceKind kind) {
    switch (kind) {
      case ChoiceKind.free:
        return '무료';
      case ChoiceKind.condition:
        return '조건';
      case ChoiceKind.premium:
        return '프리미엄';
    }
  }

  Future<void> _watchRewardAdSkeleton({String placement = 'premium_token_daily'}) async {
    final limit = placement == 'premium_token_daily' ? 3 : 10;
    final ok = await _consumeAdView(placement, limit);
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('오늘 광고 시청 한도 도달 ($limit회)')));
      return;
    }
    _playReward();
    _premiumTokens += 1;
    _logs.insert(0, '[광고 보상:$placement] 프리미엄 토큰 +1');
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('보상 광고 시청(시뮬레이션): 프리미엄 토큰 +1')));
    setState(() {});
  }

  Future<void> _applyPremiumSample(Map<String, dynamic> sample, {bool consumeToken = true}) async {
    final targetName = sample['targetName']?.toString() ?? _story[_storyIndex].leftCharacter;
    final target = _characterByName(targetName);
    if (consumeToken) {
      _premiumTokens = max(0, _premiumTokens - 1);
    }

    final affinity = sample['affectionAdd'] as int? ?? 0;
    if (affinity != 0) {
      await _addAffection(target, affinity, '[프리미엄]');
    }

    final statDelta = <String, int>{};
    final stats = (sample['statDelta'] as Map<String, dynamic>? ?? {});
    for (final e in stats.entries) {
      statDelta[e.key] = e.value as int;
    }
    if (statDelta.isNotEmpty) {
      _applyPoliticalDelta(statDelta, '프리미엄 샘플');
    }

    final setFlags = (sample['setFlags'] as Map<String, dynamic>? ?? {});
    for (final e in setFlags.entries) {
      _keyFlags[e.key] = e.value == true;
    }

    if ((sample['preserveEvidence'] as bool? ?? false) && _evidenceOwned.isNotEmpty) {
      _logs.insert(0, '[프리미엄] 증거 카드 보존 효과 발동');
    }

    if ((sample['grantItem'] as String?) != null) {
      _evidenceOwned.add(sample['grantItem'].toString());
      _logs.insert(0, '[프리미엄] 아이템 획득: ${sample['grantItem']}');
    }
    if (sample['id'] == 'B5') {
      _premiumTokens += 1;
      _logs.insert(0, '[프리미엄] 완주 보상: 토큰 1개 환급');
    }

    _refreshRelationshipStateFor(target, source: '프리미엄 샘플');
    await _save();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('프리미엄 장면 · ${sample['title']}'),
        content: Text('${sample['scene']}\n\n효과: ${sample['effectText']}'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
    setState(() {});
  }

  Future<void> _openPremiumChoiceFlow(StoryBeat beat) async {
    final node = _storyIndex + 1;
    final samples = _premiumSamplesForNode(node);
    if (samples.isEmpty) {
      await _usePremiumChoice(beat);
      return;
    }

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: const Color(0xFF191624),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('프리미엄 선택지', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text('감정씬 확장/관계 전환 보정/편의 효과 중 하나를 제공합니다.', style: TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 10),
            ...samples.map(
              (s) => Card(
                color: const Color(0xFF2A2340),
                child: ListTile(
                  title: Text(s['title'].toString(), style: const TextStyle(color: Colors.white)),
                  subtitle: Text(s['scene'].toString(), style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                  onTap: () => Navigator.pop(context, s),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final open = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('프리미엄 선택지'),
        content: const Text('이 선택은 감정씬(추가 대사+보이스)로 확장됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'later'), child: const Text('다음에')),
          TextButton(onPressed: () => Navigator.pop(context, 'ad'), child: const Text('광고 보고 열기')),
          FilledButton(onPressed: () => Navigator.pop(context, 'token'), child: const Text('토큰 1개 사용')),
        ],
      ),
    );
    if (open == null || open == 'later') return;
    if (open == 'ad') {
      final ok = await _consumeAdView('premium_open', 10);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오늘 프리미엄 광고 개방 한도 도달')));
        return;
      }
    } else if (_premiumTokens <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('토큰이 부족합니다. 광고로 먼저 획득하세요.')));
      return;
    }

    if (open == 'token') {
      await _applyPremiumSample(picked, consumeToken: true);
    } else {
      final clone = Map<String, dynamic>.from(picked);
      clone['affectionAdd'] = (clone['affectionAdd'] as int? ?? 0) - 1;
      await _applyPremiumSample(clone, consumeToken: false);
    }
  }

  Future<void> _openAttachedPremiumForChoice(StoryBeat beat, StoryChoice choice, int choiceIndex, Map<String, dynamic> sample) async {
    if (_endingCharacterName != null) return;

    final open = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('추가 장면(프리미엄)'),
        content: Text('${sample['title']}\n\n${sample['scene']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'later'), child: const Text('무료 선택 유지')),
          TextButton(onPressed: () => Navigator.pop(context, 'ad'), child: const Text('광고 보고 열기')),
          FilledButton(onPressed: () => Navigator.pop(context, 'token'), child: const Text('토큰 1개 사용')),
        ],
      ),
    );

    if (open == null || open == 'later') return;

    if (open == 'ad') {
      final ok = await _consumeAdView('premium_open', 10);
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('오늘 프리미엄 광고 개방 한도 도달')));
        return;
      }
    } else if (_premiumTokens <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('토큰이 부족합니다.')));
      return;
    }

    final premiumChoice = StoryChoice(
      label: '[프리미엄] ${choice.label}',
      mainTarget: choice.mainTarget,
      mainDelta: choice.mainDelta,
      result: '${choice.result}\n(추가 장면: ${sample['title']})',
      sideTarget: choice.sideTarget,
      sideDelta: choice.sideDelta,
      kind: ChoiceKind.premium,
    );

    await _pickStoryChoice(premiumChoice, choiceIndex);
    await _applyPremiumSample(sample, consumeToken: open == 'token');
  }

  Future<void> _usePremiumChoice(StoryBeat beat) async {
    if (_premiumTokens <= 0 || _endingCharacterName != null) return;
    final primary = _characterByName(beat.leftCharacter);
    final secondary = _characterByName(beat.rightCharacter);
    final target = primary.affection >= secondary.affection ? primary : secondary;
    final synthetic = StoryChoice(
      label: '[프리미엄] 결속의 서약',
      mainTarget: target.name,
      mainDelta: 16,
      result: '프리미엄 선택으로 감정과 정치의 결속이 크게 강화되었다.',
      kind: ChoiceKind.premium,
    );
    _premiumTokens -= 1;
    await _pickStoryChoice(synthetic, 99);
    _applyPoliticalDelta({
      _characterPoliticalStat(target.name): 10,
      'publicTrust': 4,
      'surveillance': -2,
    }, '프리미엄 선택');
    _refreshRelationshipStateFor(target, source: '프리미엄');
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _maybeShowCrisisRescue() async {
    final s = _politicalStats['surveillance'] ?? 0;
    if (s < 80 || !mounted) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('[위기] 감시망 포착'),
        content: const Text('당신은 고발당했습니다. 대응이 필요합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'evidence'), child: const Text('증거 제출(1장 소모)')),
          TextButton(onPressed: () => Navigator.pop(context, 'gold'), child: const Text('금화로 무마(500G)')),
          TextButton(onPressed: () => Navigator.pop(context, 'ad'), child: const Text('긴급 변호인(광고 1회/일)')),
        ],
      ),
    );
    if (choice == null) return;

    if (choice == 'evidence') {
      if (_evidenceOwned.isNotEmpty) {
        _evidenceOwned.remove(_evidenceOwned.first);
        _applyPoliticalDelta({'surveillance': -8}, '위기 구제');
      }
    } else if (choice == 'gold') {
      if (_gold >= 500) {
        _gold -= 500;
        _applyPoliticalDelta({'surveillance': -10}, '위기 구제');
      }
    } else {
      final ok = await _consumeAdView('crisis_lawyer', 1);
      if (ok) {
        _applyPoliticalDelta({'surveillance': -12, 'publicTrust': 2}, '긴급 변호인');
      }
    }
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _evaluateEndingIfNeeded(int pickedNodeIndex, String resultText) async {
    if (pickedNodeIndex != 29 || _endingEvaluated) return;
    final decision = _evaluateEndingDecision();
    if (decision == null) return;
    _endingRuleId = decision.id;
    _endingRuleType = decision.type;
    _endingEvaluated = true;
    _logs.insert(0, '[엔딩 판정] ${decision.id} (${decision.type})');
    await _save();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('엔딩 판정'),
        content: Text('ending id: ${decision.id}\nending type: ${decision.type}\n\n스토리 결과: $resultText'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
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
      decoration: BoxDecoration(
        image: const DecorationImage(image: AssetImage('assets/ui/panel_parchment_dark.png'), fit: BoxFit.fill),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('목표', style: TextStyle(color: Color(0xFFF6F1E8), fontWeight: FontWeight.w700, shadows: [Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 1))])),
          SizedBox(height: 3),
          Text('1) 호감도 100 선점', style: TextStyle(color: Color(0xFFF6F1E8), fontSize: 12)),
          Text('2) 분기 루트 개방', style: TextStyle(color: Color(0xFFF6F1E8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _topBottomScrim() {
    return IgnorePointer(
      child: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x8C000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
          const Spacer(flex: 5),
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xA6000000), Color(0x00000000)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sealPrimaryButton(String label, VoidCallback? onPressed) {
    return SizedBox(height: 68, child: _SealButton(label: label, onPressed: onPressed, onClickSfx: _playClick));
  }

  Widget _buildBottomNav() {
    final items = [
      ('assets/ui/nav_gen/nav_home_gen.png', '홈'),
      ('assets/ui/nav_gen/nav_story_gen.png', '스토리'),
      ('assets/ui/nav_gen/nav_date_gen.png', '데이트'),
      ('assets/ui/nav_gen/nav_work_gen.png', '아르바이트'),
      ('assets/ui/nav_gen/nav_shop_gen.png', '제작/상점'),
      ('assets/ui/nav_gen/nav_ledger_gen.png', '장부'),
      ('assets/ui/nav_gen/nav_codex_gen.png', '도감'),
      ('assets/ui/nav_gen/nav_settings_gen.png', '설정'),
    ];

    return SizedBox(
      height: 150,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
        decoration: BoxDecoration(
          color: const Color(0xCC2A1D44),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB79C63), width: 1.2),
        ),
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            childAspectRatio: 1.6,
            mainAxisSpacing: 4,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, i) => _BottomNavItem(
            iconPath: items[i].$1,
            label: items[i].$2,
            selected: i == _menuIndex,
            onTap: () {
              _playClick();
              setState(() {
                _menuIndex = i;
                _menuOverlayOpen = false;
              });
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 84,
        title: SizedBox(
          height: 70,
          child: Stack(
            children: [
              Positioned.fill(child: Image.asset('assets/ui/top_hud_frame_v4.png', fit: BoxFit.fill)),
              Positioned(
                left: 58,
                top: 23,
                child: Row(
                  children: [
                    _hudCurrency('assets/ui/icon_gold.png', _gold.toString(), shortLabel: 'G'),
                    const SizedBox(width: 8),
                    _hudCurrency('assets/ui/icon_silk.png', _evidenceOwned.length.toString(), shortLabel: 'S'),
                    const SizedBox(width: 8),
                    _hudCurrency('assets/ui/icon_token.png', _premiumTokens.toString(), shortLabel: 'T'),
                  ],
                ),
              ),
              Positioned(
                right: 14,
                top: 18,
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(0.22)),
                  onPressed: () => setState(() => _menuIndex = 7),
                  icon: const Icon(Icons.add, color: Color(0xFFF6F1E8), size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween<double>(begin: 0.985, end: 1).animate(animation), child: child),
            ),
            child: KeyedSubtree(key: ValueKey(_menuIndex), child: _buildMenuPage(_menuIndex)),
          ),
          if (_menuOverlayOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(top: false, child: _buildBottomNav()),
            ),
          Positioned(
            right: 12,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: FloatingActionButton.extended(
                heroTag: 'menu_fab',
                onPressed: () {
                  _playClick();
                  setState(() => _menuOverlayOpen = !_menuOverlayOpen);
                },
                backgroundColor: const Color(0xFF6A4BFF),
                foregroundColor: const Color(0xFFF6F1E8),
                icon: Icon(_menuOverlayOpen ? Icons.close : Icons.menu),
                label: Text(_menuOverlayOpen ? '닫기' : '메뉴'),
              ),
            ),
          ),
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
        return _datePage();
      case 3:
        return _workPage();
      case 4:
        return _shopPage();
      case 5:
        return _ledgerPage();
      case 6:
        return _codexPage();
      case 7:
      default:
        return _settingsPage();
    }
  }

  Widget _homePage() {
    final outfit = _outfits.firstWhere((e) => e.id == _equippedOutfitId);

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.18))),
        Positioned.fill(child: _topBottomScrim()),

        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(bottom: 20, child: Image.asset('assets/ui/ground_shadow.png', width: 320)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: SizedBox(
                  key: ValueKey(_playerAvatar),
                  child: _fullBodySprite(_playerAvatar, width: 250),
                ),
              ),
              Positioned(left: 18, top: 120, child: GestureDetector(onTap: _showQuickInventory, child: Image.asset('assets/ui/equip_slot_ring.png', width: 48))),
              Positioned(right: 18, top: 120, child: GestureDetector(onTap: _showQuickInventory, child: Image.asset('assets/ui/equip_slot_brooch.png', width: 48))),
              Positioned(left: 24, bottom: 120, child: GestureDetector(onTap: _showQuickInventory, child: Image.asset('assets/ui/equip_slot_cloak.png', width: 48))),
              Positioned(right: 24, bottom: 120, child: GestureDetector(onTap: _showQuickInventory, child: Image.asset('assets/ui/equip_slot_dress.png', width: 48))),
            ],
          ),
        ),

        Positioned(
          top: 18,
          left: 12,
          child: Container(
            width: 186,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(image: const DecorationImage(image: AssetImage('assets/ui/panel_parchment_dark.png'), fit: BoxFit.fill), borderRadius: BorderRadius.circular(10)),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: const [
                Chip(label: Text('📘 1', style: TextStyle(fontSize: 11))),
                Chip(label: Text('💗 1', style: TextStyle(fontSize: 11))),
                Chip(label: Text('🔧 1', style: TextStyle(fontSize: 11))),
              ],
            ),
          ),
        ),

        Positioned(
          top: 16,
          right: 12,
          child: Container(
            width: 190,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/mini_inventory_sheet.png'), fit: BoxFit.fill)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('장착: ${outfit.name}', style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold)),
                Text('총 매력: $_totalCharm', style: const TextStyle(color: Colors.black87, fontSize: 12)),
              ],
            ),
          ),
        ),

        const SizedBox.shrink(),

        Positioned.fill(child: IgnorePointer(child: Image.asset('assets/ui/foreground_vignette.png', fit: BoxFit.cover))),

        Positioned(
          left: 12,
          right: 12,
          bottom: 70,
          child: Card(
            color: Colors.black.withOpacity(0.56),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('오늘의 추천', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Row(children: [Icon(Icons.favorite, size: 14, color: Colors.pinkAccent), SizedBox(width: 4), Text('추천 데이트: 신뢰 + 관계 진전', style: TextStyle(color: Color(0xFFF6F1E8), fontSize: 12))]),
                        SizedBox(height: 2),
                        Row(children: [Icon(Icons.construction, size: 14, color: Colors.orangeAccent), SizedBox(width: 4), Text('추천 알바: 골드/재료', style: TextStyle(color: Color(0xFFF6F1E8), fontSize: 12))]),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: _sealPrimaryButton('다음 노드', () {
                      setState(() => _menuIndex = 1);
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 호감도 패널은 '오늘의 추천'보다 위 레이어/위치에 표시
        Positioned(
          left: 12,
          right: 12,
          top: 84,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            offset: _showAffectionOverlay ? Offset.zero : const Offset(0, -0.16),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showAffectionOverlay ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _characters
                      .map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(width: 36, child: Text(c.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 66,
                                child: Text(
                                  _relationshipLabel(_relationshipStates[c.name] ?? RelationshipState.strange),
                                  style: const TextStyle(color: Colors.amberAccent, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: LinearProgressIndicator(value: c.affection / 100, minHeight: 8)),
                              const SizedBox(width: 8),
                              SizedBox(width: 30, child: Text('${c.affection}', style: const TextStyle(color: Colors.white))),
                              SizedBox(width: 32, child: _deltaBadge(c.name)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),

        Positioned(
          left: 12,
          bottom: 12,
          child: FilledButton.icon(
            onPressed: () {
              _playClick();
              setState(() => _showAffectionOverlay = !_showAffectionOverlay);
            },
            icon: Icon(_showAffectionOverlay ? Icons.expand_more : Icons.expand_less),
            label: Text(_showAffectionOverlay ? '호감도 닫기' : '호감도 열기'),
          ),
        ),
      ],
    );
  }

  Widget _hudCurrency(String icon, String value, {String shortLabel = ''}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Image.asset(icon, width: 24, height: 24),
          const SizedBox(width: 6),
          Text(shortLabel.isEmpty ? value : '$shortLabel $value', style: const TextStyle(fontSize: 15, color: Color(0xFFF6F1E8), fontWeight: FontWeight.w600)),
        ],
      ),
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
    final mq = MediaQuery.of(context);
    final usableH = mq.size.height - mq.padding.top - mq.padding.bottom;
    final panelH = (usableH * 0.72).clamp(520.0, 760.0);
    final headerTop = panelH * 0.02;
    final startTop = panelH * 0.15;
    final mapTop = panelH * 0.28;
    final mapBottom = panelH * 0.08;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: panelH,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 360),
                    child: SizedBox.expand(
                      key: ValueKey(_sceneBackgroundAssetForNode(_storyIndex)),
                      child: Image.asset(_sceneBackgroundAssetForNode(_storyIndex), fit: BoxFit.cover),
                    ),
                  ),
                ),
                Positioned.fill(child: Container(color: Colors.black.withOpacity(0.28))),
                Positioned.fill(child: _topBottomScrim()),
                Positioned(
                  left: 12,
                  right: 12,
                  top: headerTop,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('클리어 $cleared/${_story.length}', style: const TextStyle(color: Color(0xFFF6F1E8), fontWeight: FontWeight.w700, fontSize: 16, shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)])),
                              Text('현재: EP ${_storyIndex + 1} · ${preview.title}', style: const TextStyle(color: Color(0xFFF6F1E8))),
                              if (_endingCharacterName != null)
                                Text('확정 엔딩: $_endingCharacterName', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        IconButton(onPressed: _showStoryLegend, icon: const Icon(Icons.help_outline, color: Color(0xFFF6F1E8))),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: mapTop,
                  bottom: mapBottom,
                  child: _branchRouteMap(height: panelH - mapTop - mapBottom),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: startTop,
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.42),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _sealPrimaryButton('선택 노드 시작', () {
                              setState(() {
                                _inStoryScene = true;
                                _sceneKey += 1;
                                _transitionPreset = TransitionPreset.fade;
                              });
                              _beginBeatLine();
                            }),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '현재 노드 재탭으로 즉시 시작',
                              style: TextStyle(color: Color(0xFFF6F1E8), fontSize: 11, shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _nodeTypeIconAsset(int beat) {
    if (beat % 5 == 0) return 'assets/ui/node_icon_trial.png';
    if (beat % 5 == 1) return 'assets/ui/node_icon_emotion.png';
    if (beat % 5 == 2) return 'assets/ui/node_icon_ceremony.png';
    if (beat % 5 == 3) return 'assets/ui/node_icon_investigate.png';
    return 'assets/ui/node_icon_ceremony.png';
  }

  String _nodeTypeLabel(int beat) {
    if (beat % 5 == 0) return '재판 분기';
    if (beat % 5 == 1) return '감정 분기';
    if (beat % 5 == 2) return '의전 체크';
    if (beat % 5 == 3) return '조사 노드';
    return '스토리 노드';
  }

  Future<void> _showStoryLegend() async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('노드 아이콘 안내'),
        content: const Text('🌹 감정 · ⚖ 재판 · 👗 의전 · 📜 조사\n⚠ 위험 뱃지는 감시도/배드 위험을 의미합니다.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  Future<void> _showNodePreview(int beat) async {
    final b = _story[beat];
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('EP ${beat + 1}. ${b.title}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('유형: ${_nodeTypeLabel(beat)} · 예상 6~8분'),
            const SizedBox(height: 6),
            const Text('필요 조건: 이전 노드 클리어'),
            Text('추천 의상 태그: ${beat % 3 == 0 ? '왕실색' : beat % 3 == 1 ? '은등회' : '길드'}'),
          ],
        ),
      ),
    );
  }

  Widget _branchRouteMap({required double height}) {
    // 30-stage vertical route with in-between branch-like lane changes
    final viewH = height.clamp(280.0, 620.0).toDouble();
    const stepGap = 126.0;
    const laneX = [34.0, 174.0, 314.0];

    final lanePattern = [1, 0, 2, 1, 2, 0, 1, 2, 1, 0, 2, 1, 0, 1, 2, 1, 2, 0, 1, 0, 2, 1, 2, 1, 0, 1, 2, 0, 1, 2];
    final totalSteps = _story.length; // 30
    final mapH = 170 + (totalSteps - 1) * stepGap;

    final nodes = <Map<String, int>>[];
    for (int i = 0; i < totalSteps; i++) {
      nodes.add({'id': i, 'beat': i, 'lane': lanePattern[i % lanePattern.length], 'step': i});
    }

    Offset nodePos(Map<String, int> n) {
      final x = laneX[n['lane']!];
      // 하단 메뉴/브라우저 바에 첫 노드가 가리지 않도록 시작점을 위로 올림
      final y = mapH - 126 - (n['step']! * stepGap);
      return Offset(x, y);
    }

    final links = <List<int>>[];
    for (int i = 0; i < totalSteps - 1; i++) {
      links.add([i, i + 1]);
      // 보조 분기선은 겹침이 적은 구간에만 제한적으로 추가
      if (i % 6 == 2 && i + 2 < totalSteps) {
        final laneA = nodes[i]['lane']!;
        final laneB = nodes[i + 2]['lane']!;
        if ((laneA - laneB).abs() <= 1) {
          links.add([i, i + 2]);
        }
      }
    }

    return Container(
      height: viewH,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: SingleChildScrollView(
        reverse: true,
        child: SizedBox(
          height: mapH,
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () {
                          _playClick();
                          if (beat == _storyIndex) {
                            setState(() {
                              _inStoryScene = true;
                              _sceneKey += 1;
                              _transitionPreset = TransitionPreset.fade;
                            });
                            _beginBeatLine();
                            return;
                          }
                          setState(() {
                            _storyIndex = beat;
                            _nodeDialogueIndex = 0;
                            _lockRouteAtNode15IfNeeded();
                          });
                        },
                        onLongPress: () => _showNodePreview(beat),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected ? const Color(0xFF7E67FF) : (done ? const Color(0xFF8A6B4D) : const Color(0xFF364A66)),
                            border: Border.all(color: Colors.white70),
                            boxShadow: selected ? [const BoxShadow(color: Color(0xCC7E67FF), blurRadius: 10)] : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(_nodeTypeIconAsset(beat), width: 12, height: 12),
                              Text('${n['id']! + 1}', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        if (selected) Positioned(top: -16, right: -10, child: Image.asset('assets/ui/node_current_flag.png', width: 24)),
                        if (beat % 5 == 0) const Positioned(bottom: -8, right: -8, child: Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orangeAccent)),
                      ],
                    ),
                      ),
                      const SizedBox.shrink(),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missionConditionPanel() {
    final unlock = _evaluateUnlockRule('knight_pov_1');
    final template = _evaluateTemplateRule('normal', [
      {'type': 'affectionThreshold', 'target': 'knight', 'value': 40},
      {'type': 'politicalStatThreshold', 'stat': 'military', 'value': 35},
      {'type': 'flagTrue', 'flag': 'publicly_supported_me'},
    ]);
    final ok = unlock.unlocked && template.unlocked;

    return Container(
      width: 320,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('조건 선택 미션', style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 4),
          Text(ok ? '충족: 기사 시점 분기 가능' : '미충족: 호감도·정치수치·플래그 확인', style: TextStyle(color: ok ? Colors.lightGreenAccent : Colors.orangeAccent, fontSize: 11)),
          if (!ok) Text('${unlock.reason} ${template.reason}'.trim(), style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _storyScenePage() {
    final beat = _story[_storyIndex];
    final speakerChar = _speakerCharacterForBeat(beat);

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
                        child: Image.asset(_sceneBackgroundAssetForNode(_storyIndex), fit: BoxFit.cover),
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
                Positioned(top: 54, left: 10, child: _missionConditionPanel()),
                Positioned(top: 10, right: 10, child: _objectivePanel()),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 128,
                  child: Center(child: _centerSpeakerPortrait(speakerChar)),
                ),
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

  Character _speakerCharacterForBeat(StoryBeat beat) {
    final speaker = _currentSpeaker();
    for (final c in _characters) {
      if (speaker.contains(c.name)) return c;
    }
    return _characterByName(beat.leftCharacter);
  }

  Widget _centerSpeakerPortrait(Character c) {
    return GestureDetector(
      onTap: () async {
        if (_endingCharacterName != null) return;
        _playClick();
        await _addAffection(c, 1, '[상호작용]');
        await _save();
        if (mounted) setState(() {});
      },
      child: Container(
        width: 320,
        height: 430,
        alignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Align(
            // 머리는 고정으로 살리고, 하단(무릎 아래)만 잘라내는 프레이밍
            alignment: Alignment.topCenter,
            widthFactor: 1,
            heightFactor: 0.82,
            child: _characterImageWithExpression(c, width: 340),
          ),
        ),
      ),
    );
  }

  Widget _checkpointChoicePanel() {
    final cp = _currentCheckpoint();
    if (cp == null) return const SizedBox.shrink();
    final title = cp['title']?.toString() ?? '중간 선택';
    final options = (cp['options'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options
                .map((o) => OutlinedButton(
                      onPressed: () => _applyCheckpointChoice(o),
                      child: Text(o['label']?.toString() ?? '선택'),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _dialogWindow(StoryBeat beat) {
    return GestureDetector(
      onTap: () {
        if (!_lineCompleted) {
          _typingTimer?.cancel();
          setState(() {
            _visibleLine = _currentDialogueLines()[_nodeDialogueIndex.clamp(0, _currentDialogueLines().length - 1)]['line'] ?? beat.line;
            _lineCompleted = true;
          });
          return;
        }
        if (_isCheckpointPending()) {
          _openCheckpointPopup(beat);
        } else {
          _nextDialogueLine();
        }
      },
      child: Container(
        key: ValueKey('dialog_fixed_${_storyIndex}_${_nodeDialogueIndex}_$_lineCompleted'),
        height: 290,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        color: Colors.black.withOpacity(0.78),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text('${_currentSpeaker()} · ${beat.title}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w700))),
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
              SizedBox(height: 72, child: Text(_visibleLine, style: const TextStyle(color: Colors.white, fontSize: 15))),
              const SizedBox(height: 10),
              Expanded(
                child: _lineCompleted
                    ? SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_hasNextDialogueLine() && !_isCheckpointPending())
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: Text('click', style: TextStyle(color: Colors.white60, fontSize: 12)),
                              ),
                            if (_isCheckpointPending())
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: Text('체크포인트 선택 필요 (화면 탭)', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
                              ),
                            if (!_hasNextDialogueLine() && !_isCheckpointPending())
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(beat.choices.length, (i) {
                                  final choice = beat.choices[i];
                                  final routeLocked = _isChoiceBlockedByRouteLock(choice);
                                  final kind = i == beat.choices.length - 1 ? ChoiceKind.condition : ChoiceKind.free;
                                  final premiumSample = _premiumSampleForChoice(_storyIndex + 1, choice, choiceIndex: i);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(backgroundColor: kind == ChoiceKind.free ? null : Colors.indigo.withOpacity(0.72)),
                                        onPressed: (_endingCharacterName != null || routeLocked)
                                            ? null
                                            : () => _pickStoryChoice(
                                                  StoryChoice(
                                                    label: choice.label,
                                                    mainTarget: choice.mainTarget,
                                                    mainDelta: choice.mainDelta,
                                                    result: choice.result,
                                                    sideTarget: choice.sideTarget,
                                                    sideDelta: choice.sideDelta,
                                                    kind: kind,
                                                  ),
                                                  i,
                                                ),
                                        icon: Icon(kind == ChoiceKind.free ? Icons.radio_button_unchecked : Icons.key, size: 16),
                                        label: Text('[${_choiceKindLabel(kind)}] ${choice.label}'),
                                      ),
                                      if (premiumSample != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC3B3FF), side: const BorderSide(color: Color(0xFF7E67FF))),
                                            onPressed: (_endingCharacterName != null || routeLocked)
                                                ? null
                                                : () => _openAttachedPremiumForChoice(beat, choice, i, premiumSample),
                                            icon: const Icon(Icons.auto_awesome, size: 16),
                                            label: Text('[프리미엄] 추가 장면 · ${premiumSample['title']}'),
                                          ),
                                        ),
                                    ],
                                  );
                                }),
                              ),
                            if (_lockedRouteCharacterName != null && _storyIndex >= 14)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('루트 잠금 활성: $_lockedRouteCharacterName', style: const TextStyle(color: Colors.amberAccent, fontSize: 12)),
                              ),
                            const SizedBox(height: 2),
                          ],
                        ),
                      )
                    : const Text('탭하여 대사 넘기기', style: TextStyle(color: Colors.white54, fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dotSprite({
    required String asset,
    required int row,
    required int frame,
    int frameWidth = 32,
    int frameHeight = 48,
    double scale = 1.8,
  }) {
    final w = frameWidth * scale;
    final h = frameHeight * scale;
    return SizedBox(
      width: w,
      height: h,
      child: ClipRect(
        child: Transform.translate(
          offset: Offset(-frame * w, -row * h),
          child: Image.asset(
            asset,
            width: frameWidth * 4 * scale,
            height: frameHeight * 4 * scale,
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }

  Widget _workActorOverlay(BoxConstraints c) {
    final frame = _animTick % 4;
    int heroRow = 0;
    if (_failFlash) {
      heroRow = 3;
    } else if (_combo >= 2) {
      heroRow = 2;
    } else if (_workTimeLeft > 0) {
      heroRow = 1;
    }

    if (_selectedWork == WorkMiniGame.herbSort || _selectedWork == WorkMiniGame.courierRun || _selectedWork == WorkMiniGame.gardenWalk) {
      final tile = min(c.maxWidth, c.maxHeight) / 7;
      final p = _selectedWork == WorkMiniGame.herbSort ? _herbPos : (_selectedWork == WorkMiniGame.courierRun ? _courierPos : _gardenPos);
      return Positioned(
        left: p.x * tile + tile * 0.15,
        top: p.y * tile + tile * 0.05,
        child: _dotSprite(asset: 'assets/ui/dot_hero_sheet.png', row: heroRow, frame: frame, scale: tile / 32 * 1.15),
      );
    }

    if (_selectedWork == WorkMiniGame.haggling) {
      return Stack(
        children: [
          Positioned(left: 18, bottom: 10, child: _dotSprite(asset: 'assets/ui/dot_hero_sheet.png', row: heroRow, frame: frame, scale: 2.0)),
          Positioned(right: 18, bottom: 10, child: _dotSprite(asset: 'assets/ui/dot_npc_merchant_sheet.png', row: _combo >= 2 ? 1 : 0, frame: frame, scale: 2.0)),
        ],
      );
    }

    return Positioned(left: c.maxWidth * 0.45, bottom: 16, child: _dotSprite(asset: 'assets/ui/dot_hero_sheet.png', row: heroRow, frame: frame, scale: 2.0));
  }

  Widget _workMiniCard(String top, String title, WorkMiniGame game) {
    final selected = _selectedWork == game;
    return InkWell(
      onTap: () => setState(() => _selectedWork = game),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6F54A8) : const Color(0xFF3B324C),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFFE9D7A1) : Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(top, style: const TextStyle(fontSize: 11, color: Color(0xFFF6F1E8))),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF6F1E8))),
          ],
        ),
      ),
    );
  }

  Widget _workTab(String label, WorkMiniGame game) {
    final selected = _selectedWork == game;
    return InkWell(
      onTap: () {
        _playClick();
        setState(() => _selectedWork = game);
        if (_workTimeLeft > 0) _prepareWorkRound();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF6F54A8) : const Color(0xFF6A523C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? const Color(0xFFE9D7A1) : const Color(0xFFB28A62), width: 2),
          boxShadow: selected ? [const BoxShadow(color: Color(0x887E67FF), blurRadius: 8)] : null,
        ),
        child: Text(label, style: const TextStyle(color: Color(0xFFF6F1E8), fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _workPage() {
    final sceneBg = switch (_selectedWork) {
      WorkMiniGame.herbSort => 'assets/ui/minigame_herbfield_bg.png',
      WorkMiniGame.smithTiming => 'assets/ui/minigame_stable_bg.png',
      WorkMiniGame.haggling => 'assets/ui/minigame_market_bg.png',
      WorkMiniGame.courierRun => 'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
      WorkMiniGame.dateDance => 'assets/generated/bg_ballroom/001-luxurious-medieval-ballroom-interior-at-.png',
      WorkMiniGame.gardenWalk => 'assets/ui/minigame_herbfield_bg.png',
    };

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        const Text('도트 액션 미니게임', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 360,
            color: Colors.black,
            child: Stack(
              children: [
                Positioned.fill(child: Image.asset(sceneBg, fit: BoxFit.cover)),
                Positioned.fill(child: Container(color: _failFlash ? const Color(0x66FF0000) : Colors.transparent)),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Text('⏱ $_workTimeLeft', style: const TextStyle(color: Colors.white)),
                        const SizedBox(width: 10),
                        Text('점수 $_workScore', style: const TextStyle(color: Colors.white)),
                        const SizedBox(width: 10),
                        Text('콤보 x$_combo', style: const TextStyle(color: Colors.amberAccent)),
                        const Spacer(),
                        SizedBox(width: 34, height: 34, child: _characterImageWithExpression(_characters.first, width: 28)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 54,
                  left: 10,
                  right: 10,
                  bottom: 74,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      color: Colors.black.withOpacity(0.35),
                      alignment: Alignment.center,
                      child: const Text('플레이 시작 시 전체화면 Flame 캔버스로 전환됩니다', style: TextStyle(color: Color(0xFFF6F1E8))),
                    ),
                  ),
                ),
                if (_cutinCharacter != null)
                  Positioned(
                    right: 12,
                    top: 90,
                    child: AnimatedSlide(
                      duration: const Duration(milliseconds: 120),
                      offset: _cutinTicks > 0 ? Offset.zero : const Offset(1, 0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE9D7A1))),
                        child: Row(
                          children: [
                            _dotSprite(asset: _cutinSheet(_cutinCharacter!), row: 2, frame: _animTick % 4, scale: 1.6),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_cutinCharacter!, style: const TextStyle(color: Color(0xFFF6F1E8), fontWeight: FontWeight.w700)),
                                Text(_cutinLine, style: const TextStyle(color: Color(0xFFF6F1E8), fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(8)),
                    child: const Text('좌하단 조이스틱 이동 · 우하단 액션 버튼', style: TextStyle(color: Color(0xFFF6F1E8), fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _workMiniCard('오늘 추천', '약초 채집', WorkMiniGame.herbSort)),
            const SizedBox(width: 8),
            Expanded(child: _workMiniCard('주간 이벤트', '대장간 단조', WorkMiniGame.smithTiming)),
            const SizedBox(width: 8),
            Expanded(child: _workMiniCard('자유 플레이', '시장 흥정', WorkMiniGame.haggling)),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => showModalBottomSheet(
              context: context,
              builder: (_) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _workTab('전달 임무', WorkMiniGame.courierRun),
                  const SizedBox(height: 8),
                  _workTab('무도회', WorkMiniGame.dateDance),
                  const SizedBox(height: 8),
                  _workTab('정원 산책', WorkMiniGame.gardenWalk),
                ],
              ),
            ),
            child: const Text('더 보기'),
          ),
        ),
        const SizedBox(height: 10),
        _sealPrimaryButton('플레이 시작 (20초 루프)', _workTimeLeft > 0 ? null : _startFlameGame),
      ],
    );
  }

  Future<void> _showGiftTargetPicker(ShopItem item) async {
    final selected = await showModalBottomSheet<Character>(
      context: context,
      showDragHandle: true,
      builder: (_) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text('${item.name} 선물 대상 선택', style: const TextStyle(fontWeight: FontWeight.w700)),
          ..._characters.map((c) => ListTile(
                leading: SizedBox(width: 40, height: 54, child: _characterImageWithExpression(c, width: 34)),
                title: Text(c.name),
                subtitle: Text(c.role),
                onTap: () => Navigator.pop(context, c),
              )),
        ],
      ),
    );
    if (selected != null) {
      await _buyGift(item, selected);
    }
  }

  Widget _shopPage() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('의상/제작 상점 (외형/매력 + 연출/대사 변화)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('예: 은등회 베일 세트 → 원장 데이트 대사 2종 추가', style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 8),
        ..._outfits.map((o) => Card(
              child: ListTile(
                leading: SizedBox(width: 42, height: 52, child: _fullBodySprite(o.avatarAsset, width: 34)),
                title: Text('${o.name}  (+${o.charmBonus} 매력)'),
                subtitle: Text('${o.price == 0 ? '기본 의상' : '${o.price} G'}  · 태그:${o.id.contains('noble') ? '왕실색' : o.id.contains('ranger') ? '길드' : '은등회'}  · 효과:💬🎞'),
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
                    Align(
                      alignment: Alignment.centerRight,
                      child: SizedBox(
                        width: 120,
                        child: _sealPrimaryButton('선물하기', () => _showGiftTargetPicker(item)),
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _datePage() {
    int toNext(Character c) {
      final now = _relationshipStates[c.name] ?? RelationshipState.strange;
      final nextIdx = min(RelationshipState.values.length - 1, now.index + 1);
      final need = _affectionThreshold(RelationshipState.values[nextIdx]);
      return max(0, need - c.affection);
    }

    Future<void> startDate(Character c) async {
      final mode = _dateModeByCharacter[c.name] ?? 'short';
      await _dateRandom(c);
      if (mode == 'event') {
        await _addAffection(c, 4, '[사건데이트]');
        _applyPoliticalDelta({'publicTrust': 2}, '사건데이트');
        await _save();
      }
      if (mounted) setState(() {});
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('데이트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        const Text('캐릭터별 모드 선택 후 시작하세요.'),
        const SizedBox(height: 8),
        ..._characters.map((c) {
          final mode = _dateModeByCharacter[c.name] ?? 'short';
          final nextNeed = toNext(c);
          return Card(
            color: const Color(0xFFF4EEE2),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 72,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: _characterImageWithExpression(c, width: 52),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            Text(_relationshipLabel(_relationshipStates[c.name] ?? RelationshipState.strange)),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(value: c.affection / 100, minHeight: 8),
                            const SizedBox(height: 3),
                            Text('다음 해금 +$nextNeed (보이스 1 + 스토리 1)', style: const TextStyle(fontSize: 12, color: Color(0xFF5B4A7B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'short', label: Text('짧음')),
                            ButtonSegment(value: 'event', label: Text('사건')),
                          ],
                          selected: {mode},
                          onSelectionChanged: (s) => setState(() => _dateModeByCharacter[c.name] = s.first),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _sealPrimaryButton('시작', () => startDate(c)),
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

  Widget _ledgerPage() {
    const names = {
      'legitimacy': '👑 정통성',
      'economy': '🪙 경제력',
      'publicTrust': '🌹 민심',
      'military': '⚔ 군사',
      'surveillance': '👁 감시도',
    };

    String alertLevel(int v) => v >= 80 ? '위험' : (v >= 50 ? '주의' : '안전');
    Color alertColor(int v) => v >= 80 ? Colors.redAccent : (v >= 50 ? Colors.amber : Colors.green);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('장부', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ..._politicalStats.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${names[e.key] ?? e.key} · ${e.value}'),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(value: e.value / 100, minHeight: 10),
                ],
              ),
            )),
        const SizedBox(height: 10),
        const Text('감시도 타임라인(최근 5회)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        ..._surveillanceTimeline.asMap().entries.map((e) {
          final icons = [Icons.favorite, Icons.gavel, Icons.checkroom, Icons.search, Icons.construction];
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                SizedBox(width: 50, child: Text('D-${e.key}')),
                Icon(icons[e.key % icons.length], size: 14, color: Colors.brown),
                const SizedBox(width: 4),
                Expanded(child: LinearProgressIndicator(value: e.value / 100, minHeight: 7)),
                const SizedBox(width: 8),
                Text('${e.value}'),
              ],
            ),
          );
        }),
        Text('경고 레벨: ${alertLevel(_politicalStats['surveillance'] ?? 0)}', style: TextStyle(fontWeight: FontWeight.w700, color: alertColor(_politicalStats['surveillance'] ?? 0))),
        const SizedBox(height: 10),
        const Text('증거 카드 (필터: 길드/은등회/왕실)', style: TextStyle(fontWeight: FontWeight.bold)),
        Wrap(spacing: 6, runSpacing: 6, children: _evidenceOwned.map((e) => Chip(label: Text(e))).toList()),
        const SizedBox(height: 10),
        const Text('플래그 로그(요약)', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _logs.take(8).map((e) => Chip(label: Text(e.length > 24 ? '${e.substring(0, 24)}…' : e))).toList(),
        ),
      ],
    );
  }

  Widget _codexPage() {
    final unlocked = _evidenceOwned.length + _keyFlags.values.where((e) => e).length;
    Widget silhouetteGrid(int total, int opened) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: total,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6, childAspectRatio: 1.2),
        itemBuilder: (_, i) => Container(
          decoration: BoxDecoration(
            color: i < opened ? const Color(0xFF3E2F50) : const Color(0xFF1E1B22),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(child: Text(i < opened ? '해금' : '???', style: const TextStyle(color: Color(0xFFF6F1E8)))),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('도감', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ListTile(title: const Text('보이스'), subtitle: Text('해금 ${_keyFlags.values.where((e) => e).length}/20')),
        ListTile(title: const Text('CG'), subtitle: Text('해금 ${_evidenceOwned.length}/30')),
        ListTile(title: const Text('엔딩'), subtitle: Text(_endingRuleId == null ? '실루엣 상태 + 힌트' : '최근 해금: $_endingRuleId')),
        ListTile(title: const Text('POV'), subtitle: Text('진행도 $unlocked/40 (2/3 충족 형식)')),
        const SizedBox(height: 8),
        silhouetteGrid(9, min(9, _evidenceOwned.length)),
      ],
    );
  }

  Widget _settingsPage() {
    return Container(
      decoration: const BoxDecoration(image: DecorationImage(image: AssetImage('assets/ui/panel_parchment_light.png'), fit: BoxFit.cover)),
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('설정', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile.adaptive(
            value: _autoPlay,
            onChanged: (v) => setState(() => _autoPlay = v),
            title: const Text('오토 플레이'),
          ),
          SwitchListTile.adaptive(
            value: _skipTyping,
            onChanged: (v) {
              setState(() => _skipTyping = v);
              _beginBeatLine();
            },
            title: const Text('타이핑 스킵'),
          ),
          const ListTile(
            title: Text('광고/과금 원칙'),
            subtitle: Text('감정씬 직전·직후 강제 광고 없음\n보상형 광고 중심 노출'),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatefulWidget {
  const _BottomNavItem({required this.iconPath, required this.label, required this.selected, required this.onTap});

  final String iconPath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_BottomNavItem> createState() => _BottomNavItemState();
}

class _BottomNavItemState extends State<_BottomNavItem> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: v64.Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected ? const Color(0x557E67FF) : const Color(0x445F4A8A),
                      boxShadow: [
                        BoxShadow(
                          color: widget.selected ? const Color(0xAA7E67FF) : const Color(0x665F4A8A),
                          blurRadius: widget.selected ? 7 : 4,
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    widget.iconPath,
                    width: 26,
                    height: 26,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.apps, size: 22, color: Color(0xFFF6F1E8)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: widget.selected ? const Color(0xFFF6F1E8) : const Color(0xCCF6F1E8),
                  fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                  shadows: const [Shadow(color: Color(0x99000000), blurRadius: 4)],
                ),
              ),
              if (widget.selected)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Color(0xFFE9D7A1), shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SealButton extends StatefulWidget {
  const _SealButton({required this.label, required this.onPressed, required this.onClickSfx});

  final String label;
  final VoidCallback? onPressed;
  final VoidCallback onClickSfx;

  @override
  State<_SealButton> createState() => _SealButtonState();
}

class _SealButtonState extends State<_SealButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final body = GestureDetector(
      onTapDown: enabled
          ? (_) {
              widget.onClickSfx();
              setState(() => _pressed = true);
            }
          : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        transform: v64.Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        decoration: BoxDecoration(
          boxShadow: enabled
              ? [
                  BoxShadow(color: const Color(0x887E67FF), blurRadius: _pressed ? 4 : 10, offset: Offset(0, _pressed ? 1 : 3)),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(34),
                child: Image.asset(
                  'assets/ui/button_primary_seal_v2.png',
                  fit: BoxFit.fill,
                  centerSlice: const Rect.fromLTWH(140, 24, 240, 90),
                ),
              ),
            ),
            Positioned(
              top: 10,
              child: Container(
                width: 120,
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)]),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            Positioned.fill(
              child: Align(
                alignment: const Alignment(0, -0.25),
                child: Wrap(
                  spacing: 10,
                  children: List.generate(
                    7,
                    (i) => Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(color: Color(0xFFE9D7A1), shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Align(
                alignment: Alignment.center,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFFF6F1E8), shadows: [Shadow(color: Color(0x99000000), blurRadius: 6)]),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (enabled) return body;
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0.2126, 0.7152, 0.0722, 0, 0,
        0, 0, 0, 1, 0,
      ]),
      child: Opacity(opacity: 0.55, child: body),
    );
  }
}

class _MiniGamePainter extends CustomPainter {
  const _MiniGamePainter({
    required this.mode,
    required this.herbGrid,
    required this.herbPos,
    required this.courierPos,
    required this.courierDocs,
    required this.guards,
    required this.gardenPos,
    required this.gardenHearts,
    required this.gardenThorns,
    required this.smithMeter,
    required this.marketCursor,
    required this.hagglingTarget,
    required this.danceNeed,
  });

  final WorkMiniGame mode;
  final List<List<int>> herbGrid;
  final Point<int> herbPos;
  final Point<int> courierPos;
  final Set<String> courierDocs;
  final List<Point<int>> guards;
  final Point<int> gardenPos;
  final Set<String> gardenHearts;
  final Set<String> gardenThorns;
  final double smithMeter;
  final double marketCursor;
  final double hagglingTarget;
  final int danceNeed;

  @override
  void paint(Canvas canvas, Size size) {
    final tile = min(size.width, size.height) / 7;
    final gridPaint = Paint()..color = const Color(0x55FFFFFF);

    if (mode == WorkMiniGame.herbSort || mode == WorkMiniGame.courierRun || mode == WorkMiniGame.gardenWalk) {
      for (int y = 0; y < 7; y++) {
        for (int x = 0; x < 7; x++) {
          canvas.drawRect(Rect.fromLTWH(x * tile, y * tile, tile - 1, tile - 1), gridPaint);
          if (mode == WorkMiniGame.herbSort) {
            final c = herbGrid[y][x];
            if (c == 1) canvas.drawCircle(Offset(x * tile + tile / 2, y * tile + tile / 2), tile * 0.18, Paint()..color = Colors.greenAccent);
            if (c == 2) canvas.drawCircle(Offset(x * tile + tile / 2, y * tile + tile / 2), tile * 0.18, Paint()..color = Colors.redAccent);
            if (c == 3) canvas.drawCircle(Offset(x * tile + tile / 2, y * tile + tile / 2), tile * 0.2, Paint()..color = Colors.amberAccent);
            if (c == 4) canvas.drawRect(Rect.fromLTWH(x * tile + tile * 0.2, y * tile + tile * 0.2, tile * 0.6, tile * 0.6), Paint()..color = Colors.blueGrey);
          }
          if (mode == WorkMiniGame.courierRun && courierDocs.contains('$x:$y')) {
            canvas.drawRect(Rect.fromLTWH(x * tile + tile * 0.25, y * tile + tile * 0.25, tile * 0.5, tile * 0.5), Paint()..color = Colors.yellow.shade200);
          }
          if (mode == WorkMiniGame.gardenWalk) {
            if (gardenHearts.contains('$x:$y')) canvas.drawCircle(Offset(x * tile + tile / 2, y * tile + tile / 2), tile * 0.18, Paint()..color = Colors.pinkAccent);
            if (gardenThorns.contains('$x:$y')) canvas.drawLine(Offset(x * tile + tile * 0.25, y * tile + tile * 0.25), Offset(x * tile + tile * 0.75, y * tile + tile * 0.75), Paint()..color = Colors.red.shade900..strokeWidth = 3);
          }
        }
      }
      if (mode == WorkMiniGame.courierRun) {
        for (final g in guards) {
          canvas.drawCircle(Offset(g.x * tile + tile / 2, g.y * tile + tile / 2), tile * 0.2, Paint()..color = Colors.orange);
          final cone = Path()
            ..moveTo(g.x * tile + tile / 2, g.y * tile + tile / 2)
            ..lineTo((g.x + 2.5) * tile, (g.y + 0.5) * tile)
            ..lineTo((g.x + 2.5) * tile, (g.y - 0.5) * tile)
            ..close();
          canvas.drawPath(cone, Paint()..color = const Color(0x55FF4444));
        }
      }
      final p = mode == WorkMiniGame.herbSort ? herbPos : (mode == WorkMiniGame.courierRun ? courierPos : gardenPos);
      canvas.drawRect(Rect.fromLTWH(p.x * tile + tile * 0.22, p.y * tile + tile * 0.16, tile * 0.56, tile * 0.68), Paint()..color = const Color(0xFF7E67FF));
    } else if (mode == WorkMiniGame.smithTiming) {
      final track = Rect.fromLTWH(24, size.height * 0.45, size.width - 48, 24);
      canvas.drawRRect(RRect.fromRectAndRadius(track, const Radius.circular(12)), Paint()..color = Colors.white24);
      final gold = Rect.fromLTWH(track.left + track.width * 0.45, track.top, track.width * 0.1, track.height);
      canvas.drawRRect(RRect.fromRectAndRadius(gold, const Radius.circular(8)), Paint()..color = Colors.amber);
      final x = track.left + (track.width * smithMeter);
      canvas.drawRect(Rect.fromLTWH(x - 4, track.top - 6, 8, track.height + 12), Paint()..color = Colors.redAccent);
    } else if (mode == WorkMiniGame.haggling) {
      final track = Rect.fromLTWH(24, size.height * 0.45, size.width - 48, 24);
      canvas.drawRRect(RRect.fromRectAndRadius(track, const Radius.circular(12)), Paint()..color = Colors.white24);
      final targetX = track.left + track.width * ((hagglingTarget - 20) / 60);
      canvas.drawCircle(Offset(targetX, track.center.dy), 10, Paint()..color = Colors.amber);
      final cursorX = track.left + track.width * marketCursor;
      canvas.drawCircle(Offset(cursorX, track.center.dy), 8, Paint()..color = Colors.lightBlueAccent);
    } else {
      const arrows = ['←', '↑', '→', '↓'];
      final tp = TextPainter(textDirection: TextDirection.ltr);
      for (int i = 0; i < 4; i++) {
        final rect = Rect.fromLTWH(24 + i * ((size.width - 48) / 4), size.height * 0.4, (size.width - 56) / 4, 56);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), Paint()..color = i == danceNeed ? const Color(0xCC7E67FF) : const Color(0x66444444));
        tp.text = TextSpan(text: arrows[i], style: const TextStyle(color: Colors.white, fontSize: 28));
        tp.layout();
        tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.center.dy - tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniGamePainter oldDelegate) => true;
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

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {double dash = 6, double gap = 5}) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dash;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + gap;
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()
      ..color = const Color(0x44C0B090)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final active = Paint()
      ..color = const Color(0x88FFE08A)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    Map<String, int> byId(int id) => nodes.firstWhere((e) => e['id'] == id);

    for (final l in links) {
      final a = byId(l[0]);
      final b = byId(l[1]);
      final p1 = nodePos(a) + const Offset(17, 17);
      final p2 = nodePos(b) + const Offset(17, 17);
      final seed = ((a['id'] ?? 0) * 31 + (b['id'] ?? 0) * 17) % 7;
      final isSkipLink = ((b['id'] ?? 0) - (a['id'] ?? 0)) > 1;
      final wobble = isSkipLink ? (5.0 + seed * 0.8) : (8.0 + seed * 1.2);

      final cp1 = Offset((p1.dx * 0.70 + p2.dx * 0.30) + (seed.isEven ? wobble : -wobble), (p1.dy * 0.70 + p2.dy * 0.30));
      final cp2 = Offset((p1.dx * 0.30 + p2.dx * 0.70) + (seed.isEven ? -wobble : wobble), (p1.dy * 0.30 + p2.dy * 0.70));

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);

      final isActive = (a['beat'] == selectedBeat) || (b['beat'] == selectedBeat);
      _drawDashedPath(canvas, path, isActive ? active : base, dash: 3.8, gap: 7.2);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinkPainter oldDelegate) {
    return oldDelegate.selectedBeat != selectedBeat;
  }
}
