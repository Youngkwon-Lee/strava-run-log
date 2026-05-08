# strava-run-log

Strava 기반 러닝 기록 분석 + Discord 리포트 + SNS 초안 생성 프로젝트.

## What it does
- 최근 러닝 자동 조회 (Strava API)
- 요약: 거리/시간/페이스/고도
- 분석: split 패턴, 다음 러닝 제안
- SNS 초안: Threads / X 톤 자동 생성

## Current status
- OAuth 연동 완료
- 최신 활동 조회/상세 조회 검증 완료
- OpenClaw Skill `strava-run-log` 초안 작성 완료

## Category
running, strava, analytics, discord-bot, social-media

---

## Setup (Detailed)

### Local verification

```bash
npm test
```

### 1) Strava API 앱 만들기
1. `https://www.strava.com/settings/api` 접속
2. 앱 생성 (아이콘 업로드 필요할 수 있음)
3. 값 확인
   - `Client ID` (숫자)
   - `Client Secret` (문자열)
4. Callback Domain: `localhost` (개발용)

### 2) 시크릿 파일 준비
프로젝트 루트에 `.secrets/strava.env` 생성:

```env
STRAVA_CLIENT_ID=123456
STRAVA_CLIENT_SECRET=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
STRAVA_ACCESS_TOKEN=
STRAVA_REFRESH_TOKEN=
STRAVA_TOKEN_EXPIRES_AT=
STRAVA_ATHLETE_ID=
```

권장 권한:

```bash
chmod 600 .secrets/strava.env
```

`.gitignore`에 `.secrets/` 포함되어 있어야 함.

### 3) OAuth 1회 승인
아래 URL에서 `client_id`만 숫자로 바꿔 접속:

```text
https://www.strava.com/oauth/authorize?client_id=YOUR_CLIENT_ID&response_type=code&redirect_uri=http://localhost/exchange_token&approval_prompt=force&scope=read,activity:read_all
```

승인 후 리디렉션 URL의 `code=...` 값 획득.

### 4) code로 토큰 교환

```bash
curl -X POST https://www.strava.com/oauth/token \
  -d client_id=$STRAVA_CLIENT_ID \
  -d client_secret=$STRAVA_CLIENT_SECRET \
  -d code=$STRAVA_CODE \
  -d grant_type=authorization_code
```

응답의 값을 `strava.env`에 반영:
- `STRAVA_ACCESS_TOKEN`
- `STRAVA_REFRESH_TOKEN`
- `STRAVA_TOKEN_EXPIRES_AT`
- `STRAVA_ATHLETE_ID`

### 5) 토큰 갱신(만료 시)

```bash
curl -X POST https://www.strava.com/oauth/token \
  -d client_id=$STRAVA_CLIENT_ID \
  -d client_secret=$STRAVA_CLIENT_SECRET \
  -d grant_type=refresh_token \
  -d refresh_token=$STRAVA_REFRESH_TOKEN
```

새 `access_token`, `refresh_token`, `expires_at`로 업데이트.

### 6) 최근 활동 조회

```bash
curl -H "Authorization: Bearer $STRAVA_ACCESS_TOKEN" \
  "https://www.strava.com/api/v3/athlete/activities?per_page=1"
```

### 7) 활동 상세 조회 (split 포함)

```bash
curl -H "Authorization: Bearer $STRAVA_ACCESS_TOKEN" \
  "https://www.strava.com/api/v3/activities/{activity_id}"
```

---

## 운영 규칙 (run-log thread)

- 러닝 1회 업로드되면 아래 3개를 자동/반자동 생성:
  1. 런 요약(거리/시간/페이스/고도)
  2. 분석 한줄(split 패턴, 다음 제안)
  3. SNS 초안 2종(Threads/X)

- HR/cadence가 비면:
  - `기기 데이터 없음`으로 표기

- `max_speed`는 GPS 튐 가능성이 있어 보조 지표로만 사용

---

## Troubleshooting

### `client_id invalid`
- `STRAVA_CLIENT_ID`가 숫자인지 확인
- `client_secret`과 값이 바뀌지 않았는지 확인

### `activity:read_permission missing`
- OAuth 재승인 시 `scope=read,activity:read_all` 포함
- `approval_prompt=force`로 강제 재동의

### `Limit of connected athletes exceeded (403)`
- Strava 앱 권한 해제 후 재승인
- 필요하면 앱 재생성(`run-log-v2`) 후 재연결

---

## Vercel webhook 배포 (실시간 감지)

1. Vercel 배포
```bash
vercel --prod
```

2. Vercel 환경변수 설정
- `STRAVA_CLIENT_ID`
- `STRAVA_CLIENT_SECRET`
- `STRAVA_REFRESH_TOKEN`
- `STRAVA_ACCESS_TOKEN`
- `STRAVA_TOKEN_EXPIRES_AT`
- `STRAVA_VERIFY_TOKEN` (임의 문자열)
- `DISCORD_WEBHOOK_URL` (run-log 스레드 웹훅 URL)
- `LIVE_METRICS_TOKEN` (Apple Watch/Health bridge 인증용 임의 문자열, 권장)

3. Strava 구독 등록
```bash
export WEBHOOK_CALLBACK_URL="https://<your-vercel-domain>/api/strava/webhook"
./scripts/register_subscription.sh
```

4. 검증
- Strava 러닝 저장 → webhook POST 수신
- Discord run-log에 자동 요약 메시지 도착 확인

## Live coaching endpoint (Apple Watch/Health bridge)

실시간 데이터 브리지에서 아래 endpoint로 metrics를 push하면 코칭 메시지가 Discord로 전송됩니다.

- `POST /api/live/metrics`
- Body(JSON):
```json
{
  "session_id": "run-2026-04-14-am",
  "pace_sec": 365,
  "hr": 154,
  "distance_km": 2.4,
  "elapsed_sec": 910,
  "force": false
}
```

입력값 범위:
- `pace_sec`, `gap_sec`: 0~1800초/km (`0`은 데이터 없음)
- `hr`: 0~240 bpm
- `distance_km`: 0~200km
- `elapsed_sec`: 0~86400초
- `cadence`: 0~260 spm
- `readiness_score`: 0~100
- `force`: boolean 또는 `"true"`/`"false"`

환경변수(선택):
- `LIVE_METRICS_TOKEN` (설정 시 `Authorization: Bearer ...`, `x-live-metrics-token`, 또는 run-live-coach의 `x-live-token` 필요)
- `COACH_TARGET_PACE_SEC` (default: 370)
- `COACH_MAX_HR` (default: 175)
- `COACH_COOLDOWN_SEC` (default: 90)
- `COACH_HR_SUSTAINED_SEC` (default: 120)
- `COACH_USER_PROFILES_JSON` (user별 개인화 설정 JSON)
- `ALLOW_SIM_DISCORD_POSTS=true` (`sim-`으로 시작하는 시뮬레이터 세션도 Discord에 보내고 싶을 때만 설정)

개인화 입력 필드(선택):
- `user_id` (예: `youngkwon`)
- `readiness_score` (당일 컨디션 점수)

프로필 샘플:
- `docs/sample-user-profiles.json`

Vercel 환경변수 예시:
```bash
COACH_USER_PROFILES_JSON='{"youngkwon":{"target_pace_sec":370,"max_hr":182,"hr_sustained_sec":120,"coaching_frequency_sec":90,"readiness_score":72},"mother":{"target_pace_sec":620,"max_hr":145,"hr_sustained_sec":90,"coaching_frequency_sec":120,"readiness_score":65},"father":{"target_pace_sec":580,"max_hr":150,"hr_sustained_sec":90,"coaching_frequency_sec":120,"readiness_score":68}}'
```

테스트 예시:
```bash
curl -X POST https://strava-run-log.vercel.app/api/live/metrics \
  -H 'content-type: application/json' \
  -H "authorization: Bearer $LIVE_METRICS_TOKEN" \
  -d '{"session_id":"test-live","pace_sec":355,"hr":162,"distance_km":3.1,"elapsed_sec":1200,"force":true}'
```

### run-live-coach 연결

`run-live-coach`는 Apple Watch에서 실시간 러닝 데이터를 수집하는 앱이고, 이 프로젝트는 그 데이터를 받아 Discord 코칭으로 바꾸는 백엔드입니다.

연결하려면 `run-live-coach/watch/LiveRun/*.xcconfig`에:
- `LIVE_METRICS_URL=https://<your-vercel-project>.vercel.app/api/live/metrics`
- `LIVE_TOKEN=<LIVE_METRICS_TOKEN과 같은 값>`

을 설정합니다. `LIVE_METRICS_URL`이 있으면 `run-live-coach`는 기존 LiveRun 웹 백엔드 대신 이 endpoint로 실시간 metrics를 push합니다.

## Weekly WHO report endpoint

- `GET /api/strava/weekly-report`
- 최근 7일 러닝 기준으로 `중강도 분(WHO 150~300분/주)` 요약 계산
- `?send=true`를 붙이면 Discord로 요약 전송

예시:
```bash
curl "https://strava-run-log.vercel.app/api/strava/weekly-report"
curl "https://strava-run-log.vercel.app/api/strava/weekly-report?send=true"
```

## Roadmap
- [x] webhook 기반 실시간 감지 (Vercel)
- [x] 실시간 metrics 수신 + 코칭 메시지
- [x] 주간 WHO 기준 리포트 엔드포인트
- [ ] 페이스 추세/부하 점수 시각화
- [ ] MCP 서버로 확장
