export async function refreshTokenIfNeeded() {
  const now = Math.floor(Date.now() / 1000);
  const exp = Number(process.env.STRAVA_TOKEN_EXPIRES_AT || 0);
  if (process.env.STRAVA_ACCESS_TOKEN && exp > now + 120) return process.env.STRAVA_ACCESS_TOKEN;

  const body = new URLSearchParams({
    client_id: process.env.STRAVA_CLIENT_ID,
    client_secret: process.env.STRAVA_CLIENT_SECRET,
    grant_type: 'refresh_token',
    refresh_token: process.env.STRAVA_REFRESH_TOKEN
  });

  const r = await fetch('https://www.strava.com/oauth/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body
  });
  if (!r.ok) throw new Error(`refresh failed: ${r.status}`);
  const j = await r.json();

  process.env.STRAVA_ACCESS_TOKEN = j.access_token;
  process.env.STRAVA_REFRESH_TOKEN = j.refresh_token;
  process.env.STRAVA_TOKEN_EXPIRES_AT = String(j.expires_at);
  return j.access_token;
}

export async function getActivityDetail(activityId, token) {
  const r = await fetch(`https://www.strava.com/api/v3/activities/${activityId}`, {
    headers: { Authorization: `Bearer ${token}` }
  });
  if (!r.ok) throw new Error(`activity detail failed: ${r.status}`);
  return r.json();
}

export function summarizeActivity(d) {
  const km = ((d.distance || 0) / 1000).toFixed(2);
  const sec = d.moving_time || 0;
  const mm = Math.floor(sec / 60);
  const ss = sec % 60;
  const paceSec = d.distance ? sec / (d.distance / 1000) : 0;
  const pm = Math.floor(paceSec / 60);
  const ps = Math.round(paceSec % 60);
  return {
    title: d.name || 'Run',
    km,
    moving: `${mm}:${String(ss).padStart(2, '0')}`,
    pace: `${pm}:${String(ps).padStart(2, '0')}/km`,
    paceSec,
    elev: d.total_elevation_gain ?? 0
  };
}

function secToPace(secPerKm) {
  const m = Math.floor(secPerKm / 60);
  const s = Math.round(secPerKm % 60);
  return `${m}:${String(s).padStart(2, '0')}/km`;
}

export function buildCoachingComment(detail, opts = {}) {
  const targetPaceSec = Number(opts.targetPaceSec ?? 370); // default 6:10/km
  const targetRpe = opts.targetRpe ?? '6~7';

  const paceSec = detail.distance ? (detail.moving_time || 0) / (detail.distance / 1000) : null;
  if (!paceSec) return `코칭: 데이터 부족. 다음 런은 목표 페이스 ${secToPace(targetPaceSec)} 기준으로 시작해봐요.`;

  const diff = paceSec - targetPaceSec;
  let paceAdvice = '';
  if (diff <= -15) {
    paceAdvice = `초반이 빠른 편입니다(목표 대비 ${Math.abs(Math.round(diff))}초 빠름). 다음 런은 첫 1km를 ${secToPace(targetPaceSec)} 근처로 눌러 시작해요.`;
  } else if (diff >= 20) {
    paceAdvice = `오늘은 목표 대비 ${Math.round(diff)}초 느렸어요. 다음 런은 보폭 줄이고 케이던스 유지로 ${secToPace(targetPaceSec + 5)}부터 맞춰봅시다.`;
  } else {
    paceAdvice = `페이스가 목표 범위에 잘 들어왔어요. 다음 런도 ${secToPace(targetPaceSec)} ±10초로 유지하면 좋습니다.`;
  }

  const splits = detail.splits_metric || [];
  let splitAdvice = '';
  if (splits.length >= 3) {
    const first = splits.slice(0, Math.max(1, Math.floor(splits.length / 2)));
    const last = splits.slice(Math.floor(splits.length / 2));
    const avg = (arr) => arr.reduce((a, x) => a + ((x.moving_time || x.elapsed_time || 0) / Math.max((x.distance || 1000) / 1000, 0.1)), 0) / arr.length;
    const firstAvg = avg(first);
    const lastAvg = avg(last);
    const trend = lastAvg - firstAvg;
    if (trend <= -10) splitAdvice = '후반 가속(negative split) 패턴이 좋아요. 마지막 1km 빌드업 전략 유지 추천.';
    else if (trend >= 15) splitAdvice = '후반 페이스 하락이 보여요. 중반부터 호흡 리듬(2-2)과 팔치기 리듬을 일정하게 가져가요.';
    else splitAdvice = '구간 페이스가 안정적입니다. 현재 페이싱 전략 유지가 좋습니다.';
  }

  const hrNote = detail.average_heartrate ? `평균 HR ${Math.round(detail.average_heartrate)} 기준으로 무리 없는지 함께 체크하세요.` : '심박 데이터가 없어 RPE(목표 ' + targetRpe + ') 기준으로 강도 조절해요.';

  return `코칭: ${paceAdvice} ${splitAdvice} ${hrNote}`.replace(/\s+/g, ' ').trim();
}
