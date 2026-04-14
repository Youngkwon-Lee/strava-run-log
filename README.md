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

환경변수(선택):
- `COACH_TARGET_PACE_SEC` (default: 370)
- `COACH_MAX_HR` (default: 175)
- `COACH_COOLDOWN_SEC` (default: 90)

테스트 예시:
```bash
curl -X POST https://strava-run-log.vercel.app/api/live/metrics \
  -H 'content-type: application/json' \
  -d '{"session_id":"test-live","pace_sec":355,"hr":162,"distance_km":3.1,"elapsed_sec":1200,"force":true}'
```

## Roadmap
- [x] webhook 기반 실시간 감지 (Vercel)
- [x] 실시간 metrics 수신 + 코칭 메시지
- [ ] 주간 리포트 자동 생성
- [ ] 페이스 추세/부하 점수 시각화
- [ ] MCP 서버로 확장
