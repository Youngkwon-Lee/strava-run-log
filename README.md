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

## Quick start
1. `.secrets/strava.env`에 키 저장
2. access token 만료 시 refresh
3. `athlete/activities` + `activities/{id}` 조회
4. Discord 스레드에 요약/분석/초안 게시

## Roadmap
- [ ] webhook 기반 실시간 감지
- [ ] 주간 리포트 자동 생성
- [ ] 페이스 추세/부하 점수 시각화
- [ ] MCP 서버로 확장

## Category
running, strava, analytics, discord-bot, social-media
