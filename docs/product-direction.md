# Product Direction

## Product Thesis

`strava-run-log`는 러닝 기록을 단순히 모아두는 로그가 아니라, 여러 러닝 데이터 소스를 **Activity Event -> Human State -> Encounter insight**로 바꾸는 lightweight PGHD intelligence layer다.

## Primary User

- 개인 러너: Strava, Apple Watch, HealthKit 기록을 자동으로 모으고 싶은 사용자
- 코칭/재활 고객: 전문가가 처방한 운동과 실제 활동 반응을 연결하고 싶은 사용자
- 전문가/physio app: 고객 활동 이벤트, adherence, fatigue, training load 신호를 다음 Encounter에서 보고 싶은 사용자

현재 제품은 팀/클럽 운영툴보다 **개인 활동/재활 PGHD bridge**에 가깝다.

## Product Boundary

In scope:
- Strava OAuth 기반 활동 조회
- Apple Health/Watch bridge ingest 수신
- 러닝 기록 정규화와 히스토리 저장
- provider-originated activity event staging
- derived human state snapshot 조회
- 실시간 metrics 기반 코칭 문구 생성
- 주간 리포트와 WHO 기준 진행률
- Discord 알림과 SNS 초안 생성
- 웹 대시보드/설정 페이지

Out of scope for now:
- 의료 진단 또는 치료 조언
- Garmin/Nike 비공식 scraping
- 다중 코치/클럽 관리 기능
- 결제/구독/조직 권한 관리
- 장기 운영용 DB 스키마 완성

## Architecture Direction

The durable boundary should be:

1. Provider ingest
   - Strava OAuth/webhook
   - Apple Health bridge
   - future Garmin partner API
2. Generic PGHD activity-event model
   - one source event shape across running, walking, cycling, rehab exercise, and wearable summaries
3. Running projection
   - current dashboard/API compatibility through `run_log_runs`
   - linked back to `pghd_activity_events` when the generic table is present
4. Derived state and coaching/reporting
   - training load / adherence / fatigue snapshots
   - encounter-ready review insight derived from current state
   - post-run coaching
   - live metrics coaching
   - weekly report
5. Surfaces
   - dashboard
   - Discord
   - social draft export

`lib/run-store.js` should stay as the storage boundary so the file-backed MVP can be replaced without rewriting API handlers.

## Near-Term Priorities

1. Replace serverless `/tmp` storage with a real external store.
2. Add state views: adherence, training load, fatigue, recovery.
3. Connect `run-live-coach` bridge cleanly for live watch metrics.
4. Make Apple Health import repeatable and idempotent from mobile.
5. Improve post-run coaching with recent-history context.

## Physio App Integration

`moai_web` already has workflow tables such as `activity_sessions`. The run-log integration should keep provider-originated activity events in `pghd_activity_events` first, project running records into `run_log_runs`, then link selected records into physio app workflows when a person/care context is known.

The current state model is:

```text
Provider Raw Data
-> pghd_activity_events as normalized generic PGHD activity_event staging
-> run_log_runs as running projection/compatibility layer
-> human_state_snapshots for derived state
-> activity_sessions only when promoted into workflow context
```

See [`physio-app-integration.md`](physio-app-integration.md).

For healthcare/rehab terminology, this provider-originated data is treated as PGHD before it is attached to a clinical workflow. See [`pghd-ontology-mapping.md`](pghd-ontology-mapping.md).

## Product Positioning

Short version:

> A PGHD activity intelligence layer that turns Strava and Apple Watch data into timeline events, state signals, and encounter-ready insight.

The product should avoid becoming a generic fitness social network. Its sharper lane is **private running telemetry -> useful coaching/reporting -> optional sharing**.
