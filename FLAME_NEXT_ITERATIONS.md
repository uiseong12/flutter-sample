# Flame Iteration Plan

## Iteration 1 (완료)
- [x] flame_tiled 도입
- [x] TMX 맵 6종 분리 (`assets/minigame/*.tmx`)
- [x] Scene/Component 구조 분리
  - `lib/minigame/flame/components.dart`
  - `lib/minigame/flame/scenes.dart`
  - `lib/minigame/flame/models.dart`
- [x] 메인 미니게임 페이지와 Flame GameWidget 연동

## Iteration 2 (다음)
- [ ] 타일 충돌 레이어 분리(벽/통과불가 오브젝트)
- [ ] 모드별 오브젝트 컴포넌트 세분화(Herb/Poison/Guard/Document)
- [ ] 카메라 연출(줌, shake, success punch)

## Iteration 3
- [ ] 파티클 시스템 분리(코인/퍼플글로우/실패플래시)
- [ ] 캐릭터 애니메이터(Idle/Walk/Action/Hurt) 컴포넌트화
- [ ] 오디오 큐 시스템 도입

## Iteration 4
- [ ] 모드별 규칙 클래스 완전 독립 + 밸런스 JSON 로딩
- [ ] 결과/보상/감정선 연동을 이벤트 버스로 연결
- [ ] 테스트용 디버그 오버레이 추가
