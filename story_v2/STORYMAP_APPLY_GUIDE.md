# StoryMap 적용 가이드 (업데이트 반영본)

## 목적
`story_v2`의 챕터/노드/분기 구조를 게임 스토리맵(UI)에 그대로 표시하기 위한 기준 문서.

## 사용 파일
- 맵 데이터: `assets/story_v2/story_map_layout.json`
- 챕터-노드 인덱스: `assets/story_v2/chapter_node_index.json`
- 로더 코드: `lib/story_v2_map.dart`

## 핵심 구조
- 챕터: 30 (`C01 ~ C30`)
- 노드: 40 (분기 챕터 포함)
- 해피엔딩: 5 (`HE_*`)
- 배드엔딩: 10 (`BE_*`)

### 분기 집중 챕터
- C06: 3노드
- C13: 5노드 (루트 시작)
- C26: 5노드 (루트별 최종 이벤트)

## UI 맵 배치 규칙
- Y축: `chapter` 순서
- X축: 같은 챕터 내 노드 좌표(`x`) 사용
- 연결선: `edges[from -> to]`
- 노드 타입 색상 권장
  - `scene/route`: 기본
  - `ending_happy`: 골드
  - `ending_bad`: 레드

## 런타임 처리 주의점
1. C12에서 `route` 잠금 필요
2. C25 이후 C26은 `routeNodesAtCh26` 맵으로 라우팅
3. C30은 단순 next가 아니라 상태값 기반 엔딩 판정 필요

## 검증 체크리스트
- [ ] 맵에 노드 55개(본편+엔딩) 렌더링
- [ ] C12 선택 후 C13 루트 하나만 활성화
- [ ] C26 진입 시 route별 올바른 노드 연결
- [ ] C30에서 HE/BE가 규칙대로 분기

