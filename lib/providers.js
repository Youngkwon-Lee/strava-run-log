export const INTEGRATION_PROVIDERS = [
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
    id: 'apple-health',
    name: 'Apple Health',
    status: 'mobile_app_required',
    method: 'HealthKit iOS 권한',
    summary: 'Apple Watch/Health 기록은 웹 OAuth가 아니라 iPhone 앱에서 HealthKit 권한을 받아 읽어야 합니다.',
    actionLabel: 'iOS HealthKit 브리지 필요',
    docsUrl: 'https://developer.apple.com/documentation/healthkit',
    caveat: '서버가 Apple 계정에 OAuth로 접속해 운동 기록을 가져오는 공식 웹 API는 없습니다.'
  },
  {
    id: 'garmin',
    name: 'Garmin',
    status: 'partner_review_required',
    method: 'Garmin Health API',
    summary: '승인된 Garmin Connect Developer Program 앱은 사용자 동의 후 Garmin Connect 데이터를 받을 수 있습니다.',
    actionLabel: 'Garmin 파트너 승인 필요',
    docsUrl: 'https://developer.garmin.com/gc-developer-program/health-api/',
    caveat: '평가/상용 접근은 Garmin 승인이 필요하고 상용 라이선스 비용이 발생할 수 있습니다.'
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
