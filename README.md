# strava-run-log

Strava/Apple Health 기반 러닝 기록 분석 + PGHD activity event/state bridge + Discord 리포트 + SNS 초안 생성 프로젝트.

## What it does
- 최근 러닝 자동 조회 (Strava API)
- Apple Health bridge ingest 수신
- 공통 run history store에 러닝 기록 upsert
- Physio/rehab PGHD 타임라인용 generic activity event staging
- 주간 기록 기반 state signals: training load, adherence, fatigue
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
- `pghd_activity_events`/`run_log_runs` -> `human_state_snapshots` 기반 PGHD state signal API/대시보드 연결
- PGHD state schema는 linked Supabase에서 기능 검증 완료
- linked Supabase migration history는 PhysioApp owner lineage로 적용됐고,
  이 repo에서 broad `supabase db push`는 계속 차단됨

## Category
running, strava, analytics, discord-bot, social-media

## Product direction

이 프로젝트의 제품 초점은 **러닝/웨어러블 데이터를 Activity Event -> Human State -> Encounter insight로 바꾸는 lightweight PGHD intelligence layer**입니다.

현재는 Strava/Apple Health 입력을 받아 Discord와 웹 대시보드로 보여주고, physio app이 사용할 수 있는 PGHD weekly summary, timeline, state signals를 제공하는 MVP입니다. 저장 경계는 범용 `pghd_activity_events` staging과 러닝 특화 `run_log_runs` projection으로 나뉩니다. 단기적으로는 개인 러너용 코칭/리포트 품질과 client/person 기준 PGHD 해석 품질을 높이고, 중기적으로는 `run-live-coach` 같은 watch/mobile bridge와 결합해 실시간 코칭 경험을 안정화합니다.

자세한 방향성은 [`docs/product-direction.md`](docs/product-direction.md)를 봅니다.

physio_app 연동용 API 계약은 [`docs/physio-app-api-contract.md`](docs/physio-app-api-contract.md)를 봅니다.

실행 순서와 release/staging gate 선택 기준은
[`docs/pghd-execution-roadmap.md`](docs/pghd-execution-roadmap.md)를 봅니다.

---

## Setup (Detailed)

### Local verification

```bash
npm test
```

대시보드 inline script 구문까지 확인하려면:

```bash
node - <<'NODE'
import { readFileSync } from 'node:fs';
const html = readFileSync('index.html', 'utf8');
const scripts = [...html.matchAll(/<script[^>]*>([\s\S]*?)<\/script>/gi)].map((m) => m[1]);
for (const script of scripts) new Function(script);
console.log(`checked ${scripts.length} inline scripts`);
NODE
```

PGHD/Supabase 실제 연결까지 확인하려면 운영 DB 키가 있는 로컬 환경에서 아래 스모크를 실행합니다.

```bash
SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... npm run smoke:pghd
```

이 스모크는 기존 `pghd_connections`의 유효한 `person_id`를 재사용해 Apple Health 테스트 기록을 저장하고, `run_log_weekly_summaries` 조회와 `activity_sessions` 승격까지 확인한 뒤 생성한 테스트 row를 삭제합니다. `RUN_LOG_ADMIN_TOKEN`과 `APPLE_HEALTH_INGEST_TOKEN`이 없으면 로컬 핸들러 호출용 임시 토큰을 사용합니다. 로컬 env가 없으면 `PGHD_SMOKE_ENV_FILE` 또는 `/Users/youngkwon/projects/physio_app/.env.local`에서 `NEXT_PUBLIC_SUPABASE_URL`과 `SUPABASE_SERVICE_ROLE_KEY`를 자동으로 읽습니다.

스모크 결과의 `evidence`에는 `preflightChecks`, `preflightWarnings`,
`preflightNextActions`가 포함됩니다. `preflightStatus: "warning"`일 때는
이 필드로 durable run store 설정 문제인지, PhysioApp person/org-client context
문제인지, persisted Human State materialization 문제인지 바로 구분합니다.
`connectionSelectionMode`과 `selectedOrgClientContext`는 smoke가 encounter
handoff에 적합한 org-client subject를 찾았는지 보여줍니다.
staging에서 fallback subject를 허용하지 않으려면
`PGHD_SMOKE_REQUIRE_ORG_CLIENT_CONTEXT=1 npm run smoke:pghd`를 사용합니다.
staging DB에 재사용 가능한 org-client PGHD subject가 없다면
`npm run smoke:pghd:strict-org-client`
로 임시 PhysioApp `persons`/`organization_members`/`org_clients`/`pghd_connections`
fixture를 만들고 smoke 종료 시 연결/멤버십 row는 삭제, 임시 person은
비활성화 tombstone 처리합니다. 이 bootstrap 경로는 명시적으로 켰을 때만
동작합니다.
preflight의 persisted state까지 `ok`로 검증하려면 bootstrap과 함께
`npm run smoke:pghd:strict-full`을 사용합니다. 이 옵션은 기존 client state를
replace하지 않도록 bootstrap subject에서만 허용됩니다.

운영 배포 후에는 실제 production URL과 Vercel runtime logs까지 묶어 아래
스모크를 실행합니다.

```bash
PRODUCTION_RUN_LOG_ADMIN_TOKEN=<production-admin-token> \
npm run smoke:production
```

이 스모크는 기본 URL `https://strava-run-log.vercel.app`에서 `/index.html`의
PGHD review/quality UI 문자열, `/api/live/metrics`와
`/api/apple-health/ingest`의 unauthenticated `401`, 인증된
`/api/run-log/preflight`, 그리고 최근 10분의 Vercel error/warning logs가 비어
있는지 확인합니다. 인증 토큰은 `PRODUCTION_RUN_LOG_ADMIN_TOKEN`,
`RUN_LOG_ADMIN_TOKEN`, `LIVE_METRICS_TOKEN` 순서로 사용하며, 로컬에서는
gitignore된 `.secrets/run_log_admin.env`의 `RUN_LOG_ADMIN_TOKEN`과
`.secrets/live_metrics.env`의 `LIVE_METRICS_TOKEN`도 자동으로 읽습니다.
모든 토큰은 server-only secret으로만 다루고 git에 저장하지 않습니다. Vercel
sensitive env로 설정한 값은 CLI로 다시 읽을 수 없으므로 운영자 shell, ignored
secret file, 또는 별도 secret manager에서 주입합니다. production에
`RUN_LOG_ADMIN_TOKEN`이 설정된 경우 preflight endpoint는 해당 admin token을
요구합니다.

preflight subject는 `pghd_connections`에서 Apple Health 연결과
`org_clients` context가 있는 row를 우선 선택합니다. 명시적으로 고정하려면:

```bash
PRODUCTION_RUN_LOG_ADMIN_TOKEN=<production-admin-token> \
PRODUCTION_PGHD_SUBJECT_PERSON_ID=<person-uuid> \
npm run smoke:production
```

옵션:
- `PRODUCTION_SMOKE_BASE_URL=https://preview.example`로 대상 URL 변경
- `PRODUCTION_SMOKE_LOG_SINCE=30m`로 Vercel log 조회 창 변경
- `PRODUCTION_SMOKE_SKIP_PREFLIGHT=1` 또는 `PRODUCTION_SMOKE_SKIP_LOGS=1`은
  토큰/CLI가 없는 환경에서 공개 endpoint subset만 확인할 때 사용

GitHub Actions에서도 같은 production smoke를 실행합니다.

- Workflow: `.github/workflows/production-smoke.yml`
- Trigger: `main` push 후 자동 실행, 또는 GitHub Actions UI의 manual
  `workflow_dispatch`
- Required GitHub Secrets:
  - `RUN_LOG_ADMIN_TOKEN`: production `/api/run-log/preflight` 인증 토큰
  - `PRODUCTION_PGHD_SUBJECT_PERSON_ID`: preflight 대상 production person UUID
  - `VERCEL_TOKEN`: `vercel logs` 조회용 Vercel CLI token
- Optional GitHub Secret/Variable:
  - `VERCEL_PROJECT_ID`: Vercel project id. 없으면 repository variable
    `VERCEL_PROJECT_NAME` 또는 기본값 `strava-run-log` 사용
  - `VERCEL_PROJECT_NAME`: repository variable로 설정 가능

`main` push trigger는 Vercel production deployment가 alias되기 전 smoke가 먼저
뛰지 않도록 기본 90초 대기합니다. 수동 실행에서는 `base_url`, `log_since`,
`wait_seconds`를 입력으로 바꿀 수 있습니다.

Vercel preview build는 `vercel.json`의 `ignoreCommand`로 제어합니다.
`.github/`, `test/`, 문서만 바뀐 PR은 build를 건너뛰고, `api/`, `lib/`,
HTML, package/config 변경은 계속 build합니다.
docs-only 검증 PR에서는 Vercel check가 build 없이 성공해야 합니다.
README-only 검증은 이 규칙의 가장 작은 확인 단위입니다.

서비스 키 없이 연결된 Supabase DB 스키마만 확인하려면 아래 스모크를 실행합니다. 이 쿼리는 트랜잭션 안에서 테스트 row를 만들고 `ROLLBACK`합니다.

```bash
npm run smoke:pghd:db
```

PGHD state snapshot schema가 원격 Supabase에 적용됐는지 확인하려면:

```bash
npm run check:pghd:migration-history
npm run check:pghd:state-functional
npm run check:pghd:state-schema
```

아직 migration이 적용되지 않았다면 이 명령은 `activity_type` 컬럼과 `human_state_snapshots` 테이블이 없다고 실패합니다. 적용은 원격 DB 비밀번호가 필요합니다.

```bash
SUPABASE_DB_PASSWORD=<remote-db-password> npm run apply:pghd:state-migration
```

이 스크립트는 required migration history preflight를 먼저 실행하고, `dbPushBlocked`, pending, missing migration이 없을 때만 `supabase migration list --linked`, `supabase db push --linked --yes`, 적용 후 migration list, state schema readiness check, state DB smoke, persisted state 저장/조회 smoke로 넘어갑니다. 현재 로컬 2026-06-22 migration set이 원격 history에 없으면 `db push`는 state migration뿐 아니라 run store/PGHD link/storage policy migration도 함께 적용 대상으로 봅니다. 해당 migration들은 기존 원격 schema와 맞도록 `if not exists`/idempotent 형태로 작성되어 있습니다.

주의: linked project의 remote migration history에 로컬에 없는 과거 migration이 있으면 Supabase CLI는 `db push`를 거부합니다. 이 경우 `npm run check:pghd:migration-history`가 `dbPushBlocked: true`, remote-only migration sample, 그리고 operator용 `nextActions`를 출력합니다. 일반적인 순서는 `supabase migration fetch --linked`로 원격 history 파일을 먼저 가져온 뒤, 기능 schema와 smoke가 이미 통과한 PGHD local-only migration만 `supabase migration repair ... --status applied --linked`로 표시하는 것입니다. 이 작업은 원격 history를 바꾸므로 자동으로 실행하지 않습니다.

repair 명령을 실행하기 전에 기능 schema와 smoke proof까지 한 번에 묶은 계획을 보려면:

```bash
npm run plan:pghd:migration-reconciliation
```

이 명령은 migration history를 변경하지 않습니다. `actions[].eligible`이 `true`인 항목만 사람이 검토 후 실행할 수 있는 후보입니다.

원격 migration history를 실제로 fetch/repair하려면 명시 토큰이 필요합니다. 이
명령은 `plan:pghd:migration-reconciliation`이 functional proof를 통과하고
missing migration이 없을 때만 `supabase migration fetch --linked` 후 PGHD
local-only version만 `applied`로 repair합니다.

```bash
PGHD_MIGRATION_RECONCILE_APPLY=20260622145528 npm run apply:pghd:migration-reconciliation
```

명시 토큰 없이 실행하면 실패합니다. broad `supabase db push`를 대신 실행하지
않습니다.

`dbPushBlocked: true`지만 기능 schema만 긴급히 맞춰야 한다면 migration history를 변경하지 않는 직접 SQL 적용 fallback을 사용할 수 있습니다. 이 경로는 idempotent SQL을 `supabase db query --linked --file ...`로 실행하고 state schema/state smoke만 검증합니다.

```bash
PGHD_DIRECT_SQL_APPLY=20260622145528 npm run apply:pghd:state-sql-direct
```

이 fallback은 Supabase migration history를 해결하지 않습니다. 이후 전체 migration history를 소유한 repo에서 정식 reconcile이 필요합니다.

기능 schema와 state materialization만 검증하려면 아래 명령을 사용합니다. 이 명령이 통과해도 Supabase migration history가 reconciled 됐다는 뜻은 아닙니다.

```bash
npm run check:pghd:state-functional
```

기능 상태와 migration history 상태를 한 번에 확인하려면:

```bash
npm run check:pghd:status
```

이 명령은 `preflightSurfaceOk`, `functionalOk`, `migrationHistoryOk`,
`localMigrationHistoryOk`, `ownerBridgeApplied`, `dbPushBlocked`,
`dbPushAllowed`, `recommendedApplyPath`를 분리해
출력합니다. 현재 owner-lineage bridge가 적용된 linked DB에서는
`migrationHistoryOk: true`일 수 있지만, `localMigrationHistoryOk: false`와
`dbPushBlocked: true`가 남으면 이 repo에서 broad `supabase db push`를 하면 안
됩니다.

현재 accepted apply path까지 포함해 release gate를 확인하려면:

```bash
npm run check:pghd:release-readiness
```

이 gate는 `check:pghd:status`와 `plan:pghd:migration-reconciliation`을 함께
실행합니다. 현재 owner-lineage bridge 경로처럼 `dbPushAllowed: false`여도
검증된 적용 경로가 있으면 통과하지만, 적용 경로가 불명확하면 실패합니다.

release/staging 판단 기록을 JSON으로 남기려면:

```bash
PGHD_RELEASE_CANDIDATE=<candidate-name> \
PGHD_RELEASE_ENVIRONMENT=<local|staging|production> \
PGHD_RELEASE_COMMANDS_RUN=$'npm run gate:pghd:release\nnpm run gate:pghd:physio-release\nnpm run gate:pghd:strict-staging\nnpm run check:pghd:status' \
npm run report:pghd:release-decision
```

이 리포트는 gate 출력물을 대체하지 않습니다. 기존 release readiness 체크를
실행한 뒤 현재 readiness/apply-path 상태를 decision log 형식으로 묶습니다.
`PGHD_RELEASE_COMMANDS_RUN`에 빠진 필수 gate는
`evidence.missingGateEvidence`에 남습니다.

필수 gate를 순차 실행하고 decision record까지 한 번에 만들려면:

```bash
PGHD_RELEASE_CANDIDATE=<candidate-name> \
PGHD_RELEASE_ENVIRONMENT=<local|staging|production> \
npm run gate:pghd:decision
```

이 명령은 첫 실패 지점에서 멈추고, 성공한 명령과 누락된 gate evidence를 JSON에
남깁니다. 같은 기록은 기본적으로 `output/pghd-release-decision/latest.json`에도
저장되며, `PGHD_RELEASE_DECISION_OUTPUT`으로 경로를 바꿀 수 있습니다.

PGHD release 후보를 한 번에 검증하려면:

```bash
npm run gate:pghd:release
```

이 gate는 unit tests, dashboard viewport smoke, PGHD E2E smoke, smoke artifact
cleanup check, accepted apply-path release readiness를 순서대로 실행합니다.

Run-log readiness와 PhysioApp handoff readiness를 한 번에 운영 점검하려면:

```bash
npm run check:pghd:physio-handoff
```

이 명령은 이 repo의 PGHD release readiness와
`/Users/youngkwon/Projects/physio_app`의 production/ops readiness를 함께
확인하고, PhysioApp의 configured Run-log import route, client helper,
server config, encounter import panel, E2E fixture 계약이 유지되는지도
검사합니다. 다른 checkout을 쓰려면 `PHYSIO_APP_DIR=/path/to/physio_app`을
지정합니다.

full Run-log release gate를 먼저 돌린 뒤 PhysioApp handoff surface까지 같이
확인하려면:

```bash
npm run gate:pghd:physio-release
```

이 gate는 `gate:pghd:release`를 통과한 다음
`check:pghd:physio-handoff --static-only`로 cross-repo handoff 계약을 빠르게
검사합니다.

staging에서 임시 org-client subject와 persisted Human State까지 만들며
preflight가 완전히 `ok`가 되는지 확인하고, PhysioApp handoff surface까지 같이
확인하려면:

```bash
npm run gate:pghd:strict-staging
```

이 gate는 production release gate를 대체하지 않습니다. staging DB에서 fallback
subject 없이 encounter handoff-ready PGHD 경로를 증명하고,
`check:pghd:smoke-cleanup`으로 bootstrap connection, smoke run, active smoke
person이 남지 않았는지 확인하는 용도입니다. cleanup만 따로 확인하려면:

```bash
npm run check:pghd:smoke-cleanup
```

현재 개선계획과 migration ownership 판단은
[`docs/pghd-improvement-plan.md`](docs/pghd-improvement-plan.md)에 정리되어
있습니다. 실제 실행 순서와 command matrix는
[`docs/pghd-execution-roadmap.md`](docs/pghd-execution-roadmap.md)를 봅니다.
현재 working-tree release decision 기록은
[`docs/pghd-release-decision-working-tree-2026-06-23.md`](docs/pghd-release-decision-working-tree-2026-06-23.md)에
있습니다.

적용 후 persisted state 저장/조회만 다시 확인하려면:

```bash
npm run smoke:pghd:state
```

이 스모크는 `state-smoke` activity event를 만들고 weekly state snapshot을 materialize한 뒤, persisted snapshot이 `human_state_snapshot_inputs`로 원본 `run_log_runs` row에 연결되는지까지 확인하고 생성 row를 삭제합니다.

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
- `GET /api/integrations/providers`: Apple Health, Strava, Garmin, Apple Watch LiveRun, GPX/TCX 파일, Nike Run Club 연동 상태/방식
- `GET /api/bridge/contract`: iOS/Watch bridge가 따라야 할 endpoint, 인증, payload 계약
- `GET /api/strava/connect`: Strava OAuth 승인 시작
- `GET /api/strava/callback`: Strava 승인 후 토큰 교환
- `GET /api/strava/me`: 현재 브라우저의 연결 상태 확인
- `POST /api/strava/disconnect`: 현재 브라우저의 연결 해제
- `POST /api/run-log/promote-to-activity-session`: 저장된 러닝을 Kinnero `activity_sessions`로 연결
- `GET /api/run-log/weekly-summaries`: Supabase weekly PGHD summary view 조회
- `GET /api/run-log/timeline`: client/person 기준 run history와 `activity_sessions` 연결 상태 조회
- `GET/POST /api/pghd/connections`: provider 계정과 physio app person/client 매핑 관리
- `GET /api/run-log/encounter-insights`: Human State snapshot을 다음 encounter에서 검토할 evidence, 질문, 주의 포인트로 변환
- `POST /api/run-log/encounter-note-drafts`: 검토된 insight note를 PhysioApp `encounter_notes` draft export row로 변환하며 직접 저장하지 않음
- `POST /api/import/run-file`: GPX/TCX 파일을 저장된 러닝으로 import

서비스별 현재 전략:
- Strava: OAuth 2.0 직접 연동 완료
- Apple Health: 웹 OAuth가 아니라 iOS HealthKit 권한이 필요하므로 iPhone/Watch bridge 앱에서 연결. 백엔드 ingest API 준비 완료
- Garmin: Garmin Health API는 Developer Program 승인 후 연결
- Apple Watch LiveRun: Watch/iPhone bridge가 `POST /api/live/metrics`로 실시간 telemetry push
- GPX/TCX 파일: `/settings.html`에서 파일 업로드 가능. FIT은 바이너리 파서 연결 후 활성화
- Nike Run Club: 공식 공개 API가 없어 Nike→Strava 동기화 또는 파일 import 경로 사용

사용자별 토큰은 서버 DB 없이 암호화된 HttpOnly 쿠키에 저장됩니다. 운영 환경에는 쿠키 암호화를 위해 `STRAVA_SESSION_SECRET`을 추가로 설정하는 것을 권장합니다. 값이 없으면 `STRAVA_CLIENT_SECRET`을 사용합니다.

공개 API는 기본적으로 사용자 OAuth 세션이 없으면 `401`을 반환합니다. 기존처럼 서버 환경변수의 단일 Strava 계정을 fallback으로 쓰고 싶을 때만 `STRAVA_ALLOW_SERVER_FALLBACK=true`를 설정하세요.

Strava API 앱 설정의 Callback Domain에는 배포 도메인을 등록해야 합니다.

```text
strava-run-log.vercel.app
```

주의: 새 Strava 앱은 기본적으로 Athlete Capacity 1(Single Player Mode)입니다. 실제 여러 사용자에게 공개하려면 Strava Developer Program review를 통과해서 capacity를 늘려야 합니다.

### `GET /api/bridge/contract`

iOS/Watch bridge 앱이 런타임 또는 개발 중에 확인할 수 있는 계약 endpoint입니다.

반환 내용:
- `contractVersion`
- Apple Health workout 저장 endpoint: `POST /api/apple-health/ingest`
- Apple Watch LiveRun 실시간 코칭 endpoint: `POST /api/live/metrics`
- Human State 조회/저장 endpoint: `GET/POST /api/run-log/state-snapshots`
- Encounter Insight 조회 endpoint: `GET /api/run-log/encounter-insights`
- PhysioApp note draft export endpoint: `POST /api/run-log/encounter-note-drafts`
- 각 endpoint의 인증 헤더, 필수/선택 필드, 단위, 응답 필드
- idempotency, HealthKit 권한, live metrics 전송 주기, PGHD state/insight 검토 가이드

이 계약의 기본 원칙:
- HealthKit 권한 요청은 iOS 앱에서 처리합니다.
- 서버는 사용자 동의 후 받은 데이터만 ingest합니다.
- workout 저장은 `external_run_id`를 기준으로 idempotent upsert합니다.
- encounter note draft는 export payload만 만들며 clinical note 저장은 PhysioApp authenticated workflow에서 처리합니다.
- live metrics는 저장용이 아니라 코칭용이며, 저장할 최종 workout은 `/api/apple-health/ingest`로 보냅니다.

### `POST /api/import/run-file`

GPX/TCX 파일을 기존 run store에 저장합니다. `/settings.html`의 `GPX/FIT/TCX 업로드` 버튼은 현재 GPX/TCX 텍스트 파일을 이 endpoint로 보냅니다.

인증:
- `IMPORT_API_TOKEN`이 설정된 경우 `Authorization: Bearer <IMPORT_API_TOKEN>` 또는 `x-import-token` 필요
- 설정하지 않으면 인증 없이 동작하므로 공개 배포에서는 토큰 설정을 권장
- `/settings.html` 업로드 UI는 `401` 응답을 받으면 토큰을 입력받아 브라우저 `localStorage`에 저장한 뒤 재시도합니다.

예시:

```json
{
  "filename": "morning.gpx",
  "format": "gpx",
  "content": "<?xml version=\"1.0\"?><gpx>...</gpx>"
}
```

응답은 `source: "file-import"`로 저장된 기록 요약과 저장 결과를 반환합니다. FIT 요청은 현재 `415`로 거절됩니다.

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

이 endpoint는 payload 검증, 요약, 코칭, Discord 리포트와 함께 공통 run history store에 기록을 upsert합니다. 단, 기본 파일 저장소는 로컬/MVP용입니다. Vercel에서는 파일 backend가 기본 차단되며, 장기 운영은 Supabase/Postgres 또는 다른 외부 DB/KV/S3 어댑터가 필요합니다.

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

Supabase 모드에서는 `pghd_activity_events`가 범용 PGHD 원본 activity event staging이고, `run_log_runs`는 러닝 대시보드/주간 집계/기존 API를 위한 projection입니다. generic layer가 아직 적용되지 않은 DB에서는 `run_log_runs` upsert가 계속 동작하도록 best-effort fallback을 둡니다.

기본 저장 위치:
- 로컬: `.data/runs.jsonl`
- Vercel/serverless: 기본 차단. 임시 smoke/dev에서만 `RUN_STORE_ALLOW_EPHEMERAL_FILE=1`로 `/tmp/strava-run-log/runs.jsonl` 허용
- 직접 지정: `RUN_STORE_PATH=/path/to/runs.jsonl`
- Supabase/Postgres: `RUN_STORE_BACKEND=supabase`

저장된 기록만 조회:

```bash
curl "https://<your-domain>/api/strava/activities?source=stored&days=90&limit=50"
curl "https://<your-domain>/api/strava/weekly-report?source=stored"
```

주의: `/tmp` 기반 serverless 파일 저장은 인스턴스 재시작 시 사라질 수 있기 때문에 Vercel에서는 기본 차단됩니다. 임시 검증에만 `RUN_STORE_BACKEND=file`과 `RUN_STORE_ALLOW_EPHEMERAL_FILE=1`을 함께 사용하고, 장기 운영에서는 `RUN_STORE_BACKEND=supabase` 또는 같은 `lib/run-store.js` 경계를 유지한 외부 저장소 어댑터를 사용하세요.

자세한 저장 계약과 한계는 [`docs/run-history-store.md`](docs/run-history-store.md)를 봅니다. PGHD 데이터 관리 정책은 [`docs/pghd-data-management.md`](docs/pghd-data-management.md)를 봅니다.

#### Supabase store

Supabase Free 플랜은 개인 MVP에는 충분합니다. 러닝 요약 레코드 중심으로 저장하고 GPS streams/route points 원본을 대량 저장하지 않는 것이 전제입니다.

필요한 환경변수:

```env
RUN_STORE_BACKEND=supabase
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=<server-only-service-role-key>
RUN_STORE_SUPABASE_TABLE=run_log_runs
PGHD_ACTIVITY_EVENTS_TABLE=pghd_activity_events
```

주의:
- `SUPABASE_SERVICE_ROLE_KEY`는 서버 환경변수로만 설정하고 브라우저에 노출하지 않습니다.
- DB schema는 `supabase/migrations/`의 run store migration들을 Supabase SQL editor 또는 CLI로 적용합니다.
- `public.pghd_activity_events`와 `public.run_log_runs`는 RLS enabled 상태입니다. 현재 앱은 server-side service role 접근을 전제로 합니다.
- `run_log_weekly_summaries` view는 대시보드 주간 추세 조회용입니다.
- `RUN_STORE_MAX_RAW_BYTES` 기본값은 `65536`이고 큰 raw payload는 저장 전에 거절됩니다.
- 로컬 검증은 `scripts/smoke_supabase_run_store.mjs`로 실행합니다.

### `GET /api/strava/weekly-report`

최근 7일 러닝을 WHO 기준과 함께 요약합니다. 이제 평균 페이스, 누적 상승고도, 평균 심박/케이던스, 최장 러닝, 개별 러닝 목록도 같이 반환합니다.

### `POST /api/run-log/promote-to-activity-session`

`run_log_runs`에 저장된 provider 러닝 기록을 Kinnero/moai_web의 `activity_sessions`로 승격하고, 생성된 `activity_sessions.id`를 다시 `run_log_runs.activity_session_id`에 기록합니다.

인증:
- `Authorization: Bearer <RUN_LOG_ADMIN_TOKEN>`
- `RUN_LOG_ADMIN_TOKEN`이 없으면 `LIVE_METRICS_TOKEN` 사용

필수 body:

```json
{
  "source": "apple-health",
  "external_id": "apple_health_...",
  "subject_person_id": "11111111-1111-4111-8111-111111111111"
}
```

선택 body:
- `organization_id`
- `org_client_profile_id`
- `created_by`
- `notes`

### `GET /api/run-log/weekly-summaries`

Supabase `run_log_weekly_summaries` view를 읽어 client/person별 주간 추세를 반환합니다.

인증:
- `Authorization: Bearer <RUN_LOG_ADMIN_TOKEN>`
- `RUN_LOG_ADMIN_TOKEN`이 없으면 `LIVE_METRICS_TOKEN` 사용
- 또는 `x-run-log-token`

예시:

```bash
curl "https://<your-domain>/api/run-log/weekly-summaries?subject_person_id=<uuid>&source=apple-health&limit=12" \
  -H "authorization: Bearer $RUN_LOG_ADMIN_TOKEN"
```

필터:
- `subject_person_id`
- `organization_id`
- `org_client_profile_id`
- `user_id`
- `source`
- `after`, `before` (`YYYY-MM-DD`)
- `limit` (default `52`, max `260`)

### `GET/POST /api/pghd/connections`

provider 계정과 physio app `person_id`를 연결합니다. `/settings.html`의 `PGHD 연결 매핑` 패널에서 저장/조회할 수 있습니다.

인증:
- `Authorization: Bearer <RUN_LOG_ADMIN_TOKEN>`
- `RUN_LOG_ADMIN_TOKEN`이 없으면 `LIVE_METRICS_TOKEN` 사용
- 또는 `x-run-log-token`

POST body:

```json
{
  "person_id": "11111111-1111-4111-8111-111111111111",
  "provider": "apple-health",
  "provider_user_id": "youngkwon",
  "connection_status": "connected",
  "metadata": { "source": "settings-ui" }
}
```

GET filters:
- `person_id`
- `provider`
- `provider_user_id`
- `limit`

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
- 계약 확인: `GET /api/bridge/contract`
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
