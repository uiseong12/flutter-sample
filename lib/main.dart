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
enum RelationshipState { strange, favorable, trust, shaken, bond, alliedLovers, oath }

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
  String? _lockedRouteCharacterName;
  String? _endingRuleId;
  String? _endingRuleType;
  bool _showAffectionOverlay = false;
  final List<String> _logs = [];
  final List<_Sparkle> _sparkles = [];
  final Map<String, int> _lastDelta = {};

  final Map<String, Expression> _expressions = {};
  final Map<String, RelationshipState> _relationshipStates = {};
  final Map<String, int> _politicalStats = {
    'legitimacy': 30,
    'economy': 30,
    'publicTrust': 30,
    'military': 30,
    'surveillance': 10,
  };
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
    }

    _lockRouteAtNode15IfNeeded();
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
      _sceneKey += 1;
      _cameraSeed = '${_random.nextDouble()}';
      _transitionPreset = choice.sideDelta < 0 ? TransitionPreset.flash : TransitionPreset.slide;
    }

    _lockRouteAtNode15IfNeeded();
    await _evaluateEndingIfNeeded(pickedNodeIndex, choice.result);
    _refreshAllRelationshipStates(source: '메이저 선택');

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
    _applyPoliticalDelta({_characterPoliticalStat(target.name): 2, 'publicTrust': 1}, '상점 선물');
    _setExpression(target.name, Expression.blush);
    _refreshRelationshipStateFor(target, source: '상점');
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
    if (item.id.contains('noble')) _costumeTags.add('noble');
    if (item.id.contains('ranger')) _costumeTags.add('ranger');
    if (item.id.contains('moon')) _costumeTags.add('moon');
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

  Future<void> _watchRewardAdSkeleton() async {
    _playReward();
    _premiumTokens += 1;
    _logs.insert(0, '[광고 보상] 프리미엄 토큰 +1');
    await _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('보상 광고 시청(시뮬레이션): 프리미엄 토큰 +1')));
    setState(() {});
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: Text('🎟 $_premiumTokens')),
          ),
          if (_endingRuleId != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text('판정: $_endingRuleId/$_endingRuleType', style: const TextStyle(fontSize: 12))),
            ),
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

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            'assets/generated/bg_castle/001-medieval-fantasy-royal-castle-courtyard-.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(child: Container(color: Colors.black.withOpacity(0.28))),

        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            child: SizedBox(
              key: ValueKey(_playerAvatar),
              child: _fullBodySprite(_playerAvatar, width: 250),
            ),
          ),
        ),

        Positioned(
          top: 16,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('착용: ${outfit.name}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text('총 매력: $_totalCharm', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),

        Positioned(
          left: 12,
          right: 12,
          bottom: 20,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            offset: _showAffectionOverlay ? Offset.zero : const Offset(0, 1.1),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: _showAffectionOverlay ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.62),
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
            height: 640,
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 360),
                    child: SizedBox.expand(
                      key: ValueKey(preview.backgroundAsset),
                      child: Image.asset(preview.backgroundAsset, fit: BoxFit.cover),
                    ),
                  ),
                ),
                Positioned.fill(child: Container(color: Colors.black.withOpacity(0.38))),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.42),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('스토리 진행도 (아래 → 위)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17)),
                        const SizedBox(height: 4),
                        Text('클리어: $cleared / ${_story.length}', style: const TextStyle(color: Colors.white70)),
                        Text('현재: EP ${_storyIndex + 1}. ${preview.title}', style: const TextStyle(color: Colors.white70)),
                        if (_endingCharacterName != null)
                          Text('확정 엔딩: $_endingCharacterName', style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 92,
                  bottom: 78,
                  child: _branchRouteMap(),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: FilledButton(
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _branchRouteMap() {
    // 30-stage vertical route with in-between branch-like lane changes
    const viewH = 520.0;
    const stepGap = 122.0;
    const laneX = [48.0, 168.0, 288.0];

    final lanePattern = [1, 0, 2, 1, 2, 0, 1, 2, 1, 0, 2, 1, 0, 1, 2, 1, 2, 0, 1, 0, 2, 1, 2, 1, 0, 1, 2, 0, 1, 2];
    final totalSteps = _story.length; // 30
    final mapH = 170 + (totalSteps - 1) * stepGap;

    final nodes = <Map<String, int>>[];
    for (int i = 0; i < totalSteps; i++) {
      nodes.add({'id': i, 'beat': i, 'lane': lanePattern[i % lanePattern.length], 'step': i});
    }

    Offset nodePos(Map<String, int> n) {
      final x = laneX[n['lane']!];
      final y = mapH - 72 - (n['step']! * stepGap);
      return Offset(x, y);
    }

    final links = <List<int>>[];
    for (int i = 0; i < totalSteps - 1; i++) {
      links.add([i, i + 1]);
      // light branch-looking side links
      if (i % 5 == 2 && i + 2 < totalSteps) links.add([i, i + 2]);
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
                  child: GestureDetector(
                    onTap: () {
                      _playClick();
                      setState(() {
                        _storyIndex = beat;
                        _lockRouteAtNode15IfNeeded();
                      });
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
                      child: Text('${n['id']! + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(
                          beat.choices.length,
                          (i) {
                            final choice = beat.choices[i];
                            final routeLocked = _isChoiceBlockedByRouteLock(choice);
                            return ElevatedButton(
                              onPressed: (_endingCharacterName != null || routeLocked) ? null : () => _pickStoryChoice(choice, i),
                              child: Text(choice.label),
                            );
                          },
                        ),
                      ),
                      if (_lockedRouteCharacterName != null && _storyIndex >= 14)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '루트 잠금 활성: $_lockedRouteCharacterName',
                            style: const TextStyle(color: Colors.amberAccent, fontSize: 12),
                          ),
                        ),
                      const SizedBox(height: 10),
                      const Text('조건 선택 슬롯', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (_) {
                          final unlock = _evaluateUnlockRule('knight_pov_1');
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              OutlinedButton(
                                onPressed: unlock.unlocked && _endingCharacterName == null
                                    ? () {
                                        final choice = StoryChoice(
                                          label: '[조건] 기사 시점 개방',
                                          mainTarget: '엘리안',
                                          mainDelta: 10,
                                          result: '조건 분기: 기사 시점 단서가 해금되어 전황 판단이 유리해졌다.',
                                        );
                                        _pickStoryChoice(choice, 88);
                                      }
                                    : null,
                                child: const Text('[조건] 기사 시점 분기'),
                              ),
                              if (!unlock.unlocked) Text(unlock.reason, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text('광고/프리미엄 슬롯', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _watchRewardAdSkeleton,
                            icon: const Icon(Icons.ondemand_video),
                            label: const Text('보상 광고(+1 토큰)'),
                          ),
                          FilledButton.icon(
                            onPressed: (_premiumTokens > 0 && _endingCharacterName == null) ? () => _usePremiumChoice(beat) : null,
                            icon: const Icon(Icons.stars),
                            label: Text('프리미엄 선택 (1 토큰, 보유: $_premiumTokens)'),
                          ),
                        ],
                      ),
                    ],
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
                subtitle: Text('호감도 ${c.affection} · 관계 ${_relationshipLabel(_relationshipStates[c.name] ?? RelationshipState.strange)}'),
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
      final wobble = 10.0 + seed * 2.0;

      final cp1 = Offset((p1.dx * 0.70 + p2.dx * 0.30) + (seed.isEven ? wobble : -wobble), (p1.dy * 0.70 + p2.dy * 0.30));
      final cp2 = Offset((p1.dx * 0.30 + p2.dx * 0.70) + (seed.isEven ? -wobble : wobble), (p1.dy * 0.30 + p2.dy * 0.70));

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);

      final isActive = (a['beat'] == selectedBeat) || (b['beat'] == selectedBeat);
      _drawDashedPath(canvas, path, isActive ? active : base, dash: 4.5, gap: 6.0);
    }
  }

  @override
  bool shouldRepaint(covariant _RouteLinkPainter oldDelegate) {
    return oldDelegate.selectedBeat != selectedBeat;
  }
}
