# Standards Mapping v1 (ACSM/AHA/WHO aligned)

> 목적: 현재 run-live coaching 로직을 주요 운동 가이드라인 원칙에 매핑해 안전성과 설명가능성을 높인다.
> 주의: 본 문서는 의료 처방이 아니라 일반 운동 코칭 기준이다.

## 1) 참조 프레임

- WHO (성인 신체활동 권고): 주당 중강도 유산소 150–300분 또는 고강도 75–150분
- ACSM FITT 원칙: Frequency, Intensity, Time, Type 기반 처방
- AHA/ACSM 안전 원칙: 위험 증상 발생 시 즉시 중단/평가 권고

## 2) 현재 로직 ↔ 가이드라인 매핑

### A. Readiness 기반 강도 조절
- 구현: readiness_score에 따라 target pace 완화
  - >=75: 기본
  - 60–74: +8초 완화
  - <60: +20초 완화
- 매핑: ACSM Intensity 조절(당일 컨디션/피로 반영)

### B. 고심박 경고
- 구현: maxHr 초과 시 recover action + alert severity
- 매핑: AHA/ACSM 안전 원칙(과부하 신호 시 즉시 강도 하향)

### C. 페이스 이탈 코칭
- 구현: 목표 대비 과속/저속 분기 코칭
- 매핑: ACSM FITT의 Intensity 정밀화 + 과훈련 방지

### D. 구간별 코칭(초반/중반/후반)
- 구현: 거리 기반 phase cue
- 매핑: 운동 세션 내 페이싱 전략(부하 분산)

### E. 쿨다운 주기(메시지 과다 방지)
- 구현: COACH_COOLDOWN_SEC
- 매핑: 실행가능성/순응도(behavioral adherence) 개선

## 3) 가족/고령자 모드 권장값(보수적)

- coaching_frequency_sec: 120~180
- readiness 하한 강화: <65면 회복모드
- max_hr 보수 설정 + 고심박 지속시간 짧게(예: 60~90초)
- 메시지 톤: 지시형보다 안정형("천천히", "호흡 정리")

## 4) 중단(Stop) 트리거 권장

아래 문구는 항상 고정 출력 권장:
- 흉통/압박감
- 어지럼/실신 느낌
- 비정상 호흡곤란
- 갑작스러운 심계항진/식은땀

권고 문구:
"운동을 즉시 중단하고 필요 시 의료진 상담/응급 도움을 받으세요."

## 5) 구현 체크리스트

- [ ] user_id별 프로필 강제 적용
- [ ] readiness_score 입력 없을 때 보수 기본값 사용
- [ ] severity=alert에서 recover/stop 우선 액션
- [ ] Discord 메시지에 action/severity 표준화
- [ ] 주간 총 운동시간(WHO 기준) 리포트 추가

## 6) 디스클레이머 (앱 내 표기 권장)

- 본 코칭은 일반 피트니스 가이드이며 의료진단/치료를 대체하지 않습니다.
- 기저질환자/약물 복용자/통증 지속 시 의료진 상담 후 진행하세요.
