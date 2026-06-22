# Product Direction

## Product Thesis

`strava-run-log`는 러닝 기록을 단순히 모아두는 로그가 아니라, 여러 러닝 데이터 소스를 **개인화 코칭과 공유 가능한 리포트**로 바꾸는 lightweight run intelligence layer다.

## Primary User

- 개인 러너: Strava, Apple Watch, HealthKit 기록을 자동으로 모으고 싶은 사용자
- 코칭을 받는 러너: 실시간 페이스/심박 피드백과 러닝 후 요약을 원하는 사용자
- 기록 공유 사용자: Discord, Threads, X에 올릴 요약과 초안을 빠르게 만들고 싶은 사용자

현재 제품은 팀/클럽 운영툴보다 **개인 러너용 assistant**에 가깝다.

## Product Boundary

In scope:
- Strava OAuth 기반 활동 조회
- Apple Health/Watch bridge ingest 수신
- 러닝 기록 정규화와 히스토리 저장
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
2. Normalized run model
   - one run record shape regardless of source
3. Run history store
   - current: JSONL MVP
   - next: Postgres/KV/S3 adapter
4. Coaching/reporting
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
2. Add trend views: pace, HR, weekly distance, load, consistency.
3. Connect `run-live-coach` bridge cleanly for live watch metrics.
4. Make Apple Health import repeatable and idempotent from mobile.
5. Improve post-run coaching with recent-history context.

## Physio App Integration

`moai_web` already has workflow tables such as `activity_sessions`. The run-log integration should keep provider-originated data in `run_log_runs` first, then link selected records into physio app workflows when a person/care context is known.

See [`physio-app-integration.md`](physio-app-integration.md).

## Product Positioning

Short version:

> A personal running intelligence layer that turns Strava and Apple Watch data into live coaching, weekly insight, and shareable run summaries.

The product should avoid becoming a generic fitness social network. Its sharper lane is **private running telemetry -> useful coaching/reporting -> optional sharing**.
