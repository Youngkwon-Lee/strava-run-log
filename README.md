# strava-run-log

Strava 기반 러닝 기록 분석 + Discord 리포트 + SNS 초안 생성 프로젝트.

## What it does
- 최근 러닝 자동 조회 (Strava API)
- Apple Health bridge ingest 수신
- 공통 run history store에 러닝 기록 upsert
- 요약: 거리/시간/페이스/고도
- 상세 수집: splits, laps, HR, cadence, calories, device, route polyline, GPS streams(선택)
- 분석: split 패턴, 다음 러닝 제안
- SNS 초안: Threads / X 톤 자동 생성

## Current status
- OAuth 연동 완료
- 최신 활동 조회/상세 조회 검증 완료
- Apple Health ingest + run history store MVP 완료
- 라이브 metrics 코칭 endpoint 완료
- 대시보드/설정 페이지에서 저장된 기록 fallback 표시

## Category
running, strava, analytics, discord-bot, social-media

## Product direction

이 프로젝트의 제품 초점은 **러닝 데이터를 자동으로 모으고, 개인화 코칭과 공유 가능한 리포트로 바꾸는 lightweight run intelligence layer**입니다.

현재는 Strava/Apple Health 입력을 받아 Discord와 웹 대시보드로 보여주는 MVP입니다. 단기적으로는 개인 러너용 코칭/리포트 품질을 높이고, 중기적으로는 `run-live-coach` 같은 watch/mobile bridge와 결합해 실시간 코칭 경험을 안정화합니다.

자세한 방향성은 [`docs/product-direction.md`](docs/product-direction.md)를 봅니다.

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

## Running app integrations

### Integration hub

배포된 서비스에서 사용자는 `/settings.html`에서 연동 가능한 러닝 앱을 확인하고 Strava를 직접 연결할 수 있습니다.

- `GET /settings.html`: 연결 설정 페이지
- `GET /api/integrations/providers`: Strava, Apple Health, Garmin, Nike Run Club 연동 상태/방식
- `GET /api/strava/connect`: Strava OAuth 승인 시작
- `GET /api/strava/callback`: Strava 승인 후 토큰 교환
- `GET /api/strava/me`: 현재 브라우저의 연결 상태 확인
- `POST /api/strava/disconnect`: 현재 브라우저의 연결 해제

서비스별 현재 전략:
- Strava: OAuth 2.0 직접 연동 완료
- Apple Health: 웹 OAuth가 아니라 iOS HealthKit 권한이 필요하므로 iPhone/Watch bridge 앱에서 연결. 백엔드 ingest API 준비 완료
- Garmin: Garmin Health API는 Developer Program 승인 후 연결
- Nike Run Club: 공식 공개 API가 없어 Nike→Strava 동기화 또는 스크린샷/파일 import 경로 사용

사용자별 토큰은 서버 DB 없이 암호화된 HttpOnly 쿠키에 저장됩니다. 운영 환경에는 쿠키 암호화를 위해 `STRAVA_SESSION_SECRET`을 추가로 설정하는 것을 권장합니다. 값이 없으면 `STRAVA_CLIENT_SECRET`을 사용합니다.

공개 API는 기본적으로 사용자 OAuth 세션이 없으면 `401`을 반환합니다. 기존처럼 서버 환경변수의 단일 Strava 계정을 fallback으로 쓰고 싶을 때만 `STRAVA_ALLOW_SERVER_FALLBACK=true`를 설정하세요.

Strava API 앱 설정의 Callback Domain에는 배포 도메인을 등록해야 합니다.

```text
strava-run-log.vercel.app
```

주의: 새 Strava 앱은 기본적으로 Athlete Capacity 1(Single Player Mode)입니다. 실제 여러 사용자에게 공개하려면 Strava Developer Program review를 통과해서 capacity를 늘려야 합니다.

### `POST /api/apple-health/ingest`

HealthKit 권한을 가진 iPhone 브리지 앱이 Apple Health 러닝 요약을 서버로 보낼 때 사용합니다.

인증:
- `Authorization: Bearer <APPLE_HEALTH_INGEST_TOKEN>` 또는 `x-api-key`
- `APPLE_HEALTH_SIGNING_SECRET`가 설정된 경우 `x-signature: HMAC_SHA256_HEX(body)`

예시:

```json
{
  "external_run_id": "apple_health_9D57D7F9-4C2B-4A2A-8B70-4E47A6B9F211",
  "user_id": "youngkwon",
  "started_at": "2026-05-25T06:12:10Z",
  "ended_at": "2026-05-25T06:43:40Z",
  "distance_m": 5540.8,
  "moving_time_s": 1879,
  "elapsed_time_s": 1890,
  "elevation_gain_m": 36.1,
  "avg_hr": 165.1,
  "max_hr": 185,
  "cadence_avg": 174,
  "calories": 432,
  "device_source": "Apple Watch Ultra",
  "source_app": "Apple Health",
  "splits": [
    { "km": 1, "moving_time_s": 351, "avg_hr": 153.2 },
    { "km": 2, "moving_time_s": 338, "avg_hr": 162.1 }
  ]
}
```

응답:
- `200`: 정규화된 요약 + 코칭 문구 + Discord 전송 여부
- `400`: payload 검증 실패
- `401`: 토큰 또는 signature 오류

이 endpoint는 payload 검증, 요약, 코칭, Discord 리포트와 함께 공통 run history store에 기록을 upsert합니다. 단, 기본 파일 저장소는 로컬/MVP용이며 Vercel의 `/tmp` 저장은 재시작 시 사라질 수 있습니다. 장기 운영은 외부 DB/KV/S3 어댑터가 필요합니다.

### `GET /api/strava/activities`

최근 Strava 활동을 러닝 중심으로 정리해서 가져옵니다.

기본값:
- `days=30`
- `limit=20`
- `details=true` (`/activities/{id}` 상세 조회 포함)
- `streams=false` (GPS/심박/케이던스 배열은 크므로 필요할 때만)
- `min_distance_km=0.05` (50m 미만 테스트/오작동 기록 제외)

예시:

```bash
curl "https://<your-domain>/api/strava/activities?days=90&limit=50&details=true"
curl "https://<your-domain>/api/strava/activities?days=30&limit=10&streams=true"
curl "https://<your-domain>/api/strava/activities?include_short=true"
curl "https://<your-domain>/api/strava/activities?source=stored&days=90&limit=50"
```

주요 응답 필드:
- `summary`: 총 거리, 총 시간, 평균 페이스, 누적 상승고도, 평균 심박/케이던스, 최장 러닝
- `activities[]`: 이름, 날짜, 거리, 시간, 페이스, 상승고도, 심박, 케이던스, calories, device, visibility, splits/laps, Strava URL, route polyline
- `activities[].streams`: `streams=true`일 때 route 좌표(`latlng`), distance, time, altitude, heartrate, cadence 등

비공개/Only You 활동까지 가져오려면 OAuth 승인 URL에 아래 scope가 필요합니다.

```text
scope=read,activity:read_all
approval_prompt=force
```

### Run history store

Apple Health ingest, Strava webhook, Strava activities 조회 결과는 공통 run history store에도 upsert됩니다.

기본 저장 위치:
- 로컬: `.data/runs.jsonl`
- Vercel/serverless: `/tmp/strava-run-log/runs.jsonl`
- 직접 지정: `RUN_STORE_PATH=/path/to/runs.jsonl`
- Supabase/Postgres: `RUN_STORE_BACKEND=supabase`

저장된 기록만 조회:

```bash
curl "https://<your-domain>/api/strava/activities?source=stored&days=90&limit=50"
curl "https://<your-domain>/api/strava/weekly-report?source=stored"
```

주의: `/tmp` 기반 serverless 파일 저장은 인스턴스 재시작 시 사라질 수 있습니다. 장기 운영에서는 같은 `lib/run-store.js` 경계를 Postgres/KV/S3 같은 외부 저장소 어댑터로 교체하세요.

자세한 저장 계약과 한계는 [`docs/run-history-store.md`](docs/run-history-store.md)를 봅니다.

#### Supabase store

Supabase Free 플랜은 개인 MVP에는 충분합니다. 러닝 요약 레코드 중심으로 저장하고 GPS streams/route points 원본을 대량 저장하지 않는 것이 전제입니다.

필요한 환경변수:

```env
RUN_STORE_BACKEND=supabase
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<server-only-service-role-key>
RUN_STORE_SUPABASE_TABLE=run_log_runs
```

주의:
- `SUPABASE_SERVICE_ROLE_KEY`는 서버 환경변수로만 설정하고 브라우저에 노출하지 않습니다.
- DB schema는 `supabase/migrations/20260622014705_create_run_store.sql`을 Supabase SQL editor 또는 CLI로 적용합니다.
- `public.run_log_runs`는 RLS enabled 상태입니다. 현재 앱은 server-side service role 접근을 전제로 합니다.
- 로컬 검증은 `scripts/smoke_supabase_run_store.mjs`로 실행합니다.

### `GET /api/strava/weekly-report`

최근 7일 러닝을 WHO 기준과 함께 요약합니다. 이제 평균 페이스, 누적 상승고도, 평균 심박/케이던스, 최장 러닝, 개별 러닝 목록도 같이 반환합니다.

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
- [x] Apple Health/Strava 공통 run history store MVP
- [ ] 페이스 추세/부하 점수 시각화
- [ ] 외부 영구 저장소 어댑터(Postgres/KV/S3)
- [ ] iOS HealthKit bridge 앱과 배포 설정 정리
- [ ] MCP 서버로 확장
