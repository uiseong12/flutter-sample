# FULL REQUEST INTEGRATION CHECKLIST

## 1) 프리미엄 선택지 20개
- [x] A/B/C/D 캐릭터군 각 5개, 총 20개 데이터 추가 (`premium_choices_v1.json`)
- [x] 노드별 샘플 연결
- [x] 선택지 1:1 부착 UI (기본 선택지 아래 프리미엄 버튼)

## 2) 해금 조건/콘텐츠 JSON 구조
- [x] `premium_choices_v1.json` (meta/currencies/premiumChoices/ads)
- [x] `unlock_content_schema_v1.json` (playerState/nodes/contents/ads/iap 템플릿)
- [x] pubspec assets 등록

## 3) 광고/과금 UX 플로우
- [x] 노드 결과 화면: 다음/광고추가보상/광고토큰
- [x] 아르바이트 결과: 돌아가기/보상2배광고/추가알바광고
- [x] 프리미엄 선택: 토큰/광고/다음에
- [x] 감시도 80+ 위기 구제: 증거/금화/광고(1일1회)
- [x] 일일 광고 제한 카운트 반영

## 4) UI/UX 전반
- [x] IA 8탭: 홈/스토리/데이트/아르바이트/제작상점/장부/도감/설정
- [x] 홈: 중앙 캐릭터, 재화/AP, 오늘의 추천, 다음노드 버튼
- [x] 노드맵: 유형 아이콘/프리뷰/아래→위 구조
- [x] 스토리: 감정 게이지, 선택지 계층(무료/조건/프리미엄)
- [x] 데이트: 짧은/사건 데이트 + 다음 해금까지
- [x] 장부: 수치 막대/감시도 타임라인/증거/요약 로그
- [x] 도감: 보이스/CG/엔딩/POV 진행형 표기
- [x] 설정: 광고 원칙/옵션 표기

## 비고
- 본 환경에서 flutter/dart 실행 불가로 컴파일 검증은 로컬 필요
