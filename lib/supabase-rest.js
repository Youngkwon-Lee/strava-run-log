function getSupabaseConfig() {
  const url = String(process.env.SUPABASE_URL || '').replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SECRET_KEY;

  if (!url || !key) {
    throw new Error('missing Supabase env: SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  }

  return { url, key };
}

export function assertSimpleIdentifier(value, name = 'identifier') {
  if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(String(value || ''))) {
    throw new Error(`${name} must be a simple table identifier`);
  }
}

export function supabaseHeaders(extra = {}) {
  const { key } = getSupabaseConfig();
  return {
    apikey: key,
    authorization: `Bearer ${key}`,
    'content-type': 'application/json',
    ...extra
  };
}

export async function supabaseFetch(path, init = {}) {
  const { url } = getSupabaseConfig();
  const response = await fetch(`${url}/rest/v1${path}`, {
    ...init,
    headers: supabaseHeaders(init.headers)
  });

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new Error(`Supabase request failed: ${response.status}${text ? ` ${text.slice(0, 180)}` : ''}`);
  }

  if (response.status === 204) return null;
  return response.json();
}
