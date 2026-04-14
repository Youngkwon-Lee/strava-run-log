export async function postDiscord(text) {
  const base = process.env.DISCORD_WEBHOOK_URL;
  if (!base) return;

  const threadId = process.env.DISCORD_THREAD_ID;
  const url = threadId
    ? `${base}${base.includes('?') ? '&' : '?'}thread_id=${encodeURIComponent(threadId)}`
    : base;

  await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ content: text })
  });
}
