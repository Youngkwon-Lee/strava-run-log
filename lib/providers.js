export const INTEGRATION_PROVIDERS = [
  {
    id: 'apple-health',
    name: 'Apple 건강 앱',
    status: 'mobile_app_required',
    method: 'HealthKit iOS 권한 + ingest API',
    summary: 'iPhone 또는 Apple Watch 앱에서 HealthKit 권한을 받아 workout을 읽고, 이 서비스의 ingest API로 러닝 요약을 전송합니다.',
    actionLabel: 'Apple 건강 앱 연결',
    secondaryActionLabel: '브리지 계약',
    secondaryActionUrl: '/api/bridge/contract',
    docsUrl: 'https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data',
    caveat: '웹 서버가 Apple 계정에 OAuth로 접속해 건강 데이터를 가져오는 공식 API는 없습니다. iOS 앱 브리지가 필요합니다.',
    apiUrl: '/api/apple-health/ingest'
  },
  {
    id: 'strava',
    name: 'Strava',
    status: 'live',
    method: 'OAuth 2.0',
    summary: '사용자가 승인하면 러닝 목록, 상세 기록, route polyline, splits/laps, 심박과 케이던스를 불러옵니다.',
    actionLabel: 'Strava 연결',
    actionUrl: '/api/strava/connect?return_to=/settings.html',
    docsUrl: 'https://developers.strava.com/docs/authentication/',
    caveat: '새 Strava 앱은 기본 Athlete Capacity 1입니다. 여러 사용자를 받으려면 Strava review가 필요합니다.'
  },
  {
    id: 'garmin',
    name: 'Garmin',
    status: 'partner_review_required',
    method: 'Garmin Health API',
    summary: '승인된 Garmin Connect Developer Program 앱은 사용자 동의 후 Garmin Connect 데이터를 받을 수 있습니다.',
    actionLabel: 'Garmin 연결',
    secondaryActionLabel: '승인 전 대안: Strava 경유',
    secondaryActionUrl: '/api/strava/connect?return_to=/settings.html',
    docsUrl: 'https://developer.garmin.com/gc-developer-program/health-api/',
    caveat: '평가/상용 접근은 Garmin 승인이 필요하고 상용 라이선스 비용이 발생할 수 있습니다.'
  },
  {
    id: 'liverun-watch',
    name: 'Apple Watch LiveRun',
    status: 'watch_bridge_ready',
    method: 'Watch 앱 실시간 telemetry',
    summary: 'Watch 앱 또는 iPhone companion 앱이 거리, 페이스, 심박, 케이던스 같은 실시간 러닝 지표를 LiveRun API로 전송합니다.',
    actionLabel: 'Apple Watch LiveRun 연결',
    secondaryActionLabel: '브리지 계약',
    secondaryActionUrl: '/api/bridge/contract',
    docsUrl: 'https://developer.apple.com/documentation/healthkit/workouts_and_activity_rings',
    caveat: '실제 연결 버튼 활성화는 Watch/iOS 앱 배포와 LIVE_METRICS_TOKEN 설정 이후 가능합니다.',
    apiUrl: '/api/live/metrics'
  },
  {
    id: 'file-import',
    name: 'GPX/FIT/TCX 파일',
    status: 'manual_import_planned',
    method: '수동 파일 업로드',
    summary: '기기나 플랫폼에서 내보낸 GPX, FIT, TCX 파일을 업로드해 과거 러닝 기록을 보강하는 경로입니다.',
    actionLabel: 'GPX/FIT/TCX 업로드',
    actionType: 'file_upload',
    acceptedFileTypes: '.gpx,.tcx,.fit',
    apiUrl: '/api/import/run-file',
    docsUrl: 'https://www.topografix.com/gpx.asp',
    caveat: '현재 GPX/TCX 업로드를 지원합니다. FIT은 바이너리 파서 연결 후 활성화됩니다.'
  },
  {
    id: 'nike-run-club',
    name: 'Nike Run Club',
    status: 'no_public_api',
    method: 'Strava 동기화 또는 import',
    summary: 'NRC는 공식 공개 API가 없어 직접 OAuth 연동보다 Nike에서 Strava로 동기화한 뒤 Strava API로 받는 흐름이 현실적입니다.',
    actionLabel: 'Strava 경유 권장',
    docsUrl: 'https://about.nike.com/en/newsroom/releases/nike-run-club-app-new-features/',
    caveat: '과거 NRC 기록은 공식 API로 대량 조회하기 어렵고, 스크린샷/수동 입력/import 보조 흐름이 필요합니다.'
  }
];

export function listIntegrationProviders() {
  return INTEGRATION_PROVIDERS.map((provider) => ({ ...provider }));
}

export function getIntegrationProvider(id) {
  return listIntegrationProviders().find((provider) => provider.id === id) || null;
}
