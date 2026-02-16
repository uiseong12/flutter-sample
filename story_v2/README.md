# story_v2 - 구현 가능한 분기 스토리 패키지

## 구성
- `story_manifest.json` : 엔진에서 바로 읽는 분기 정의(노드/선택지/다음노드/효과)
- `nodes/*.md` : 노드별 스토리 본문 (분기 단위로 읽기)
- `C01.md ~ C30.md` : 챕터 단위 인덱스
- `endings/*.md` : 해피 5 + 배드 10 엔딩 본문
- `routes/*.md` : 엔딩별 추천 읽기 순서

## 엔진 적용 규칙 (요약)
1. 시작 노드: `C01_N1`
2. 노드 선택 시 `effects`를 상태값에 반영
3. `next`로 이동
4. C12에서 `route` 잠금
5. C25 이후 C26은 `route_nodes_at_ch26` 매핑으로 이동
6. C30에서 `ending_resolution` 규칙으로 최종 엔딩 결정

## 상태값 키
- `truth`, `order`, `stability`
- `love_nayeon`, `love_siyu`, `love_harin`, `love_iden`, `love_yura`
- `route`, `priority`


## 추가: 풀 원고(1~30챕터)
- `full_scripts/C01.md` ~ `full_scripts/C30.md`
- 읽기 가이드: `READ_START_HERE.md`


## 엔딩 연출 강화본
- `endings_cinematic/*.md`


## 루트별 어조 패치
- `route_tone_patches/*.md`
- 나연/시유/하린/이든/유라 루트별 대사 톤 규칙과 샘플 포함


## 에필로그 씬
- `epilogues/*.md`
- 해피엔딩 5개 + 주요 배드엔딩(09/10) 후일담 씬 포함


## 게임 시스템 재설계
- `system/GAME_SYSTEM_V2.md`
- `system/game_system_v2.json`

- `system/chapter_choice_delta_v1.csv`
- `system/LIVE_OPS_RULES_V2.md`
- `system/chapter_choice_delta_v2.csv`
- `system/BALANCE_PATCH_V2.md`
- `system/monetization_v2.json`
- `routes/ROUTE_BE_01_10_DETAILED.md`

- `routes/ROUTE_BE_01.md`
- `routes/ROUTE_BE_02.md`
- `routes/ROUTE_BE_03.md`
- `routes/ROUTE_BE_04.md`
- `routes/ROUTE_BE_05.md`
- `routes/ROUTE_BE_06.md`
- `routes/ROUTE_BE_07.md`
- `routes/ROUTE_BE_08.md`
- `routes/ROUTE_BE_09.md`
- `routes/ROUTE_BE_10.md`
