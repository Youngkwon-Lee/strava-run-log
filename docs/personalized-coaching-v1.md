# Personalized Coaching v1

## Goal
사용자(개인)별 능력/컨디션/상태에 맞춰 실시간 코칭 강도와 문구를 다르게 적용한다.

## 1) User Profile Schema (baseline)

```json
{
  "user_id": "youngkwon",
  "name": "Youngkwon",
  "age": 35,
  "sex": "M",
  "experience_level": "intermediate",
  "goals": ["easy_run", "5k_pb"],
  "baseline": {
    "target_pace_sec": 370,
    "easy_pace_sec_min": 360,
    "easy_pace_sec_max": 430,
    "resting_hr": 58,
    "max_hr_est": 185,
    "weekly_distance_km": 30
  },
  "safety": {
    "hr_alert_threshold": 178,
    "hr_sustained_sec": 120,
    "pain_stop_enabled": true,
    "fall_detection_enabled": false
  },
  "preferences": {
    "tone": "calm",
    "language": "ko",
    "coaching_frequency_sec": 90,
    "channel": "discord"
  }
}
```

## 2) Daily Readiness Schema (session context)

```json
{
  "user_id": "youngkwon",
  "date": "2026-04-15",
  "sleep_hours": 6.5,
  "fatigue": 6,
  "soreness": 3,
  "stress": 5,
  "pain_flag": false,
  "rpe_target": "6~7",
  "readiness_score": 68
}
```

## 3) Live Metrics Input (already implemented endpoint)

`POST /api/live/metrics`

```json
{
  "session_id": "run-2026-04-15-am",
  "pace_sec": 365,
  "hr": 154,
  "distance_km": 2.4,
  "elapsed_sec": 910,
  "force": false,
  "user_id": "youngkwon"
}
```

## 4) Personalization Rules v1

### Rule A: Readiness-based intensity scaling
- if `readiness_score >= 75` → target pace 유지
- if `60 <= readiness_score < 75` → target pace +5~10초 완화
- if `readiness_score < 60` → 회복런 모드(목표 +15~25초)

### Rule B: HR safety guard
- if `hr >= hr_alert_threshold` 지속 `hr_sustained_sec` 이상
  - 즉시 감속 코칭 + 1분 회복 권고
  - 반복 2회면 세션 종료 권고

### Rule C: Pace deviation coaching
- 목표 대비 20초 이상 빠름: 오버페이스 경고
- 목표 대비 25초 이상 느림: 폼/호흡/케이던스 큐 제공
- 목표 범위: 유지 칭찬 + 다음 구간 전략

### Rule D: Phase-specific cues
- 0~2km: 오버페이스 방지
- 2~4km: 호흡/리듬 유지
- 4km+: 마무리 빌드업 또는 안정 페이스 유지

## 5) Output Contract

```json
{
  "coaching_text": "실시간 코칭: ...",
  "severity": "info|warn|alert",
  "action": "maintain|slow_down|recover|stop",
  "next_check_sec": 90
}
```

## 6) Immediate integration plan
1. `user_id` 기반 프로필 로더 추가
2. `daily readiness` 입력(수동/간단 설문) 붙이기
3. `buildLiveCoaching()`에 readiness scaling 반영
4. alert severity 분리 후 Discord 메시지 prefix 적용

## 7) Safety note
- 본 시스템은 의료진단이 아닌 운동 코칭 보조 목적이다.
- 흉통/어지럼/호흡곤란 등 위험 증상 시 즉시 운동 중단 및 의료 도움 권고.
