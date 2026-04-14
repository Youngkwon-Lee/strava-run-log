function secToPace(secPerKm) {
  const m = Math.floor(secPerKm / 60);
  const s = Math.round(secPerKm % 60);
  return `${m}:${String(s).padStart(2, '0')}/km`;
}

export function buildPostRunCoaching(detail, opts = {}) {
  const targetPaceSec = Number(opts.targetPaceSec ?? 370); // 6:10/km
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

  const hrNote = detail.average_heartrate
    ? `평균 HR ${Math.round(detail.average_heartrate)} 기준으로 무리 없는지 함께 체크하세요.`
    : `심박 데이터가 없어 RPE(목표 ${targetRpe}) 기준으로 강도 조절해요.`;

  return `코칭: ${paceAdvice} ${splitAdvice} ${hrNote}`.replace(/\s+/g, ' ').trim();
}

function adjustTargetByReadiness(targetPaceSec, readinessScore) {
  if (!Number.isFinite(readinessScore)) return targetPaceSec;
  if (readinessScore >= 75) return targetPaceSec;
  if (readinessScore >= 60) return targetPaceSec + 8;
  return targetPaceSec + 20;
}

export function buildLiveCoachingDecision(metrics, opts = {}) {
  const baseTargetPaceSec = Number(opts.targetPaceSec ?? 370);
  const readinessScore = Number(opts.readinessScore);
  const targetPaceSec = adjustTargetByReadiness(baseTargetPaceSec, readinessScore);
  const maxHr = Number(opts.maxHr ?? 175);
  const hrAlertSustained = Number(opts.hrSustainedSec ?? 120);

  const paceSec = Number(metrics.paceSec ?? 0);
  const hr = Number(metrics.hr ?? 0);
  const distanceKm = Number(metrics.distanceKm ?? 0);
  const elapsedSec = Number(metrics.elapsedSec ?? 0);

  if (!paceSec) {
    return {
      text: '실시간 코칭: 페이스 데이터가 아직 부족해요. 30초 더 달린 뒤 다시 체크해요.',
      severity: 'info',
      action: 'maintain',
      nextCheckSec: Number(opts.nextCheckSec ?? 90),
      adjustedTargetPaceSec: targetPaceSec
    };
  }

  const diff = paceSec - targetPaceSec;
  let paceCue;
  let action = 'maintain';
  let severity = 'info';

  if (diff <= -20) {
    paceCue = `지금 페이스가 빠릅니다 (${secToPace(paceSec)}). 10~15초 늦춰서 ${secToPace(targetPaceSec)} 근처로.`;
    action = 'slow_down';
    severity = 'warn';
  } else if (diff >= 25) {
    paceCue = `지금은 살짝 느립니다 (${secToPace(paceSec)}). 상체 세우고 보폭보다 케이던스로 +5~10초 당겨요.`;
  } else {
    paceCue = `좋아요. 목표 페이스 범위(${secToPace(targetPaceSec)}±10초) 유지 중입니다.`;
  }

  let hrCue = '';
  if (hr) {
    if (hr >= maxHr) {
      hrCue = `심박 ${hr}로 높은 편이라 1분 완화 조깅 권장.`;
      action = 'recover';
      severity = severity === 'warn' ? 'alert' : 'warn';
      if (elapsedSec >= hrAlertSustained) {
        hrCue += ' 고심박 지속 시 세션 종료를 고려하세요.';
        severity = 'alert';
      }
    } else if (hr <= maxHr - 25 && elapsedSec > 300) {
      hrCue = `심박 ${hr}로 여유 있어요. 마지막 구간에서 소폭 가속 가능합니다.`;
    } else {
      hrCue = `심박 ${hr} 안정.`;
    }
  }

  let phaseCue = '';
  if (distanceKm >= 4.0) phaseCue = '마지막 구간: 턱 힘 빼고 팔치기 리듬만 유지하며 마무리!';
  else if (distanceKm >= 2.0) phaseCue = '중반 구간: 호흡 2-2 리듬 유지, 폼 무너지지 않게 집중.';
  else phaseCue = '초반 구간: 오버페이스 금지, 발걸음 가볍게.';

  const readinessCue = Number.isFinite(readinessScore)
    ? `오늘 readiness ${readinessScore}점 기준으로 목표 페이스를 ${secToPace(targetPaceSec)}로 조정했어요.`
    : '';

  return {
    text: `실시간 코칭: ${paceCue} ${hrCue} ${phaseCue} ${readinessCue}`.replace(/\s+/g, ' ').trim(),
    severity,
    action,
    nextCheckSec: Number(opts.nextCheckSec ?? 90),
    adjustedTargetPaceSec: targetPaceSec
  };
}

export function buildLiveCoaching(metrics, opts = {}) {
  return buildLiveCoachingDecision(metrics, opts).text;
}
