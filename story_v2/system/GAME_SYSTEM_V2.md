# GAME_SYSTEM_V2.md

## 목적
`story_v2`(첫사랑 위조 x 왕실 대역) 시나리오에 맞춰 핵심 스탯, 분기 조건, 엔딩 판정, 재화 루프를 재설계한 운영 문서.

## 1) 핵심 스탯
- **TRUTH (진실, 0~100)**: 증거의 원본성/공개 강도/폭로 축
- **ORDER (질서, 0~100)**: 제도 안정/공권력 통제/협상 축
- **STABILITY (안정, 0~100)**: 여론 폭주 억제/사회 충격 완화 축
- **WILL (의지, 0~100)**: 주인공의 정신적 지속력/판단력 축

### 루트 호감도 (개별)
- `AFF_NAYEON`
- `AFF_SIYU`
- `AFF_HARIN`
- `AFF_IDEN`
- `AFF_YURA`

## 2) 기본값
- TRUTH=35, ORDER=35, STABILITY=35, WILL=40
- AFF_* = 20

## 3) 선택지 증감 가이드
- 강한 선택: ±8~12
- 중간 선택: ±4~7
- 약한 선택: ±1~3

### 상호작용 룰
- TRUTH가 한 챕터 내 +10 이상 상승하면 STABILITY -2
- ORDER가 한 챕터 내 +10 이상 상승하면 TRUTH -1
- WILL < 25 일 때 선택 효과 80% 적용

## 4) 챕터 게이트
### C12 루트 잠금
- 자유 선택 허용, 단 경고 조건:
  - 선택 루트 호감도 < 35
  - WILL < 30

### C26 루트 이벤트 강화 조건
- 공통: WILL >= 35
- 나연: AFF_NAYEON >= 55 && TRUTH >= 55
- 시유: AFF_SIYU >= 55 && STABILITY >= 50
- 하린: AFF_HARIN >= 55 && WILL >= 50
- 이든: AFF_IDEN >= 55 && TRUTH >= 60
- 유라: AFF_YURA >= 55 && ORDER >= 55

## 5) 배드엔딩 조건(10)
- BE_01: C06 침입 실패 + WILL < 35
- BE_02: 조작의심 2회+ + TRUTH < 40
- BE_03: C17 양립강행 + WILL < 45
- BE_04: C22 판단유예 + STABILITY < 40
- BE_05: C14 실명공개 + STABILITY < 35
- BE_06: C19 불완전채택 강행 + TRUTH < 55
- BE_07: C24 비공개전환 + TRUTH < 45
- BE_08: C27 원본전면공개 + STABILITY < 45
- BE_09: ORDER >= 75 && TRUTH <= 45
- BE_10: TRUTH >= 80 && STABILITY <= 35

## 6) 해피엔딩 조건(5)
공통:
- WILL >= 45
- 선택 루트 호감도 >= 70
- BE 트리거 없음

개별:
- HE_NAYEON: TRUTH >= 70 && ORDER >= 45
- HE_SIYU: STABILITY >= 70 && WILL >= 55
- HE_HARIN: WILL >= 65 && TRUTH >= 55 && STABILITY >= 55
- HE_IDEN: TRUTH >= 78 && ORDER >= 40
- HE_YURA: ORDER >= 72 && STABILITY >= 55

## 7) 재화
### CREDITS (소프트)
- 획득: 챕터/미니게임/업적
- 사용: 코스튬/연출스킨/편의
- 권장: 챕터당 80~140

### EVIDENCE_TOKEN (하드)
- 획득: 분기 퍼펙트/주간미션/패스
- 사용:
  - 선택 재시도(2)
  - 체크포인트 복구(3)
  - 히든 로그 열람(1)

## 8) 개발 적용 포인트
- 엔진 저장 상태에 `stats`, `affection`, `currencies`, `flags` 추가
- C12/C26/C30에서 본 문서 조건식으로 분기 판정
- `story_v2/story_manifest.json` choice effect에 스탯 키를 확장해 반영 가능
