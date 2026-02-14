import 'package:flutter/material.dart';

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
    this.affection = 30,
    this.dates = 0,
    this.gifts = 0,
  });

  final String name;
  final String title;
  final String description;
  final String favoriteGift;
  int affection;
  int dates;
  int gifts;
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
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;
  int _storyIndex = 0;
  final List<String> _logs = [];

  late final List<Character> _characters = [
    Character(
      name: '엘리안',
      title: '왕실 근위대장',
      description: '원칙주의자지만 주인공 앞에서는 묘하게 다정해지는 기사.',
      favoriteGift: '은빛 브로치',
    ),
    Character(
      name: '루시안',
      title: '궁정 마법사',
      description: '차분하고 냉정하지만, 주인공의 재능에 깊은 관심을 보인다.',
      favoriteGift: '고대 마도서 조각',
    ),
  ];

  late final List<StoryEvent> _events = [
    StoryEvent(
      title: '성벽 아래의 첫 만남',
      description: '여주인공은 몰래 성을 빠져나와 시장 조사를 하던 중 두 남자와 조우한다.',
      choices: [
        StoryChoice(
          label: '엘리안에게 검술 시범을 요청한다',
          result: '엘리안은 미소를 숨기지 못했다.',
          target: '엘리안',
          affectionDelta: 12,
        ),
        StoryChoice(
          label: '루시안에게 별점술을 부탁한다',
          result: '루시안은 조용히 별의 의미를 읽어주었다.',
          target: '루시안',
          affectionDelta: 12,
        ),
      ],
    ),
    StoryEvent(
      title: '수확제의 소란',
      description: '축제 도중 소동이 벌어지고, 누구와 함께 해결할지 선택해야 한다.',
      choices: [
        StoryChoice(
          label: '엘리안과 함께 시민들을 대피시킨다',
          result: '엘리안은 당신의 용기를 인정했다.',
          target: '엘리안',
          affectionDelta: 10,
        ),
        StoryChoice(
          label: '루시안과 함께 마법 결계를 펼친다',
          result: '루시안은 당신과의 호흡에 감탄했다.',
          target: '루시안',
          affectionDelta: 10,
        ),
      ],
    ),
    StoryEvent(
      title: '비밀 정원에서의 고백',
      description: '달빛 아래, 진심을 전할 기회가 찾아온다.',
      choices: [
        StoryChoice(
          label: '엘리안에게 마음을 보여준다',
          result: '엘리안은 맹세처럼 당신의 손에 입맞췄다.',
          target: '엘리안',
          affectionDelta: 15,
        ),
        StoryChoice(
          label: '루시안에게 약속의 마법을 제안한다',
          result: '루시안은 처음으로 감정을 숨기지 못했다.',
          target: '루시안',
          affectionDelta: 15,
        ),
      ],
    ),
  ];

  Character _findCharacter(String name) {
    return _characters.firstWhere((c) => c.name == name);
  }

  void _applyChoice(StoryChoice choice) {
    setState(() {
      final character = _findCharacter(choice.target);
      character.affection = (character.affection + choice.affectionDelta).clamp(0, 100);
      _logs.insert(0, '[스토리] ${choice.result} (${character.name} +${choice.affectionDelta})');
      if (_storyIndex < _events.length - 1) {
        _storyIndex += 1;
      }
    });
    _showSnack(choice.result);
  }

  void _goDate(Character character) {
    setState(() {
      character.dates += 1;
      character.affection = (character.affection + 8).clamp(0, 100);
      _logs.insert(0, '[데이트] ${character.name}와 분수대 산책 (+8)');
    });
    _showSnack('${character.name}와 데이트를 즐겼어요.');
  }

  void _sendGift(Character character) {
    final bool favoriteBonus = character.gifts % 2 == 0;
    final int bonus = favoriteBonus ? 12 : 6;

    setState(() {
      character.gifts += 1;
      character.affection = (character.affection + bonus).clamp(0, 100);
      _logs.insert(
        0,
        '[선물] ${character.name}에게 ${favoriteBonus ? character.favoriteGift : '향초'} 전달 (+$bonus)',
      );
    });
    _showSnack('${character.name}에게 선물을 전했어요.');
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final currentEvent = _events[_storyIndex];

    final pages = [
      _buildStoryPage(currentEvent),
      _buildCharactersPage(),
      _buildEventLogPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('중세 여주 로맨스 MVP'),
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

  Widget _buildStoryPage(StoryEvent event) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
              onPressed: () => _applyChoice(choice),
              child: Text(choice.label),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '진행도: ${_storyIndex + 1} / ${_events.length}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildCharactersPage() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _characters.length,
      itemBuilder: (context, index) {
        final c = _characters[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.name} · ${c.title}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
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
      },
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
