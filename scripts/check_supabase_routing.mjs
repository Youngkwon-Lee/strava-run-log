import { existsSync, readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

export const EXPECTED_LOCAL_PROJECT_ID = 'strava-run-log';
export const EXPECTED_LINKED_PROJECT_REF = 'iwtyzcwiovuvmsodtusx';
export const EXPECTED_LOCAL_PORTS = Object.freeze({
  api: 54341,
  db: 54342,
  shadowDb: 54340,
  pooler: 54349,
  studio: 54343,
  inbucket: 54344,
  analytics: 54347
});

function readTomlValue(source, section, key) {
  const sectionPattern = section.replaceAll('.', '\\.');
  const match = source.match(
    new RegExp(`^\\[${sectionPattern}\\][\\s\\S]*?^${key}\\s*=\\s*(?:"([^"]+)"|(\\d+))`, 'm')
  );
  return match?.[1] ?? (match?.[2] ? Number(match[2]) : undefined);
}

export function inspectSupabaseRouting({ configSource, linkedProjectRef }) {
  const actual = {
    projectId: configSource.match(/^project_id\s*=\s*"([^"]+)"/m)?.[1],
    ports: {
      api: readTomlValue(configSource, 'api', 'port'),
      db: readTomlValue(configSource, 'db', 'port'),
      shadowDb: readTomlValue(configSource, 'db', 'shadow_port'),
      pooler: readTomlValue(configSource, 'db.pooler', 'port'),
      studio: readTomlValue(configSource, 'studio', 'port'),
      inbucket: readTomlValue(configSource, 'inbucket', 'port'),
      analytics: readTomlValue(configSource, 'analytics', 'port')
    },
    linkedProjectRef: linkedProjectRef || null
  };

  const errors = [];
  if (actual.projectId !== EXPECTED_LOCAL_PROJECT_ID) {
    errors.push(`local project_id must be ${EXPECTED_LOCAL_PROJECT_ID}, got ${actual.projectId ?? 'missing'}`);
  }

  for (const [name, expected] of Object.entries(EXPECTED_LOCAL_PORTS)) {
    if (actual.ports[name] !== expected) {
      errors.push(`${name} port must be ${expected}, got ${actual.ports[name] ?? 'missing'}`);
    }
  }

  const ports = Object.values(actual.ports);
  if (new Set(ports).size !== ports.length) {
    errors.push('local Supabase ports must be unique');
  }

  if (actual.linkedProjectRef && actual.linkedProjectRef !== EXPECTED_LINKED_PROJECT_REF) {
    errors.push(
      `linked project must be ${EXPECTED_LINKED_PROJECT_REF}, got ${actual.linkedProjectRef}`
    );
  }

  return { ok: errors.length === 0, actual, errors };
}

export function checkSupabaseRouting(repoRoot = process.cwd()) {
  const configPath = path.join(repoRoot, 'supabase', 'config.toml');
  const linkedRefPath = path.join(repoRoot, 'supabase', '.temp', 'project-ref');
  const linkedProjectRef = existsSync(linkedRefPath)
    ? readFileSync(linkedRefPath, 'utf8').trim()
    : undefined;

  return inspectSupabaseRouting({
    configSource: readFileSync(configPath, 'utf8'),
    linkedProjectRef
  });
}

const invokedPath = process.argv[1] ? path.resolve(process.argv[1]) : '';
if (invokedPath === fileURLToPath(import.meta.url)) {
  const result = checkSupabaseRouting();
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
  if (!result.ok) {
    process.exitCode = 1;
  } else {
    const command = process.argv[2];
    if (command) {
      if (!['start', 'status', 'stop'].includes(command)) {
        process.stderr.write('Usage: node scripts/check_supabase_routing.mjs [start|status|stop]\n');
        process.exitCode = 2;
      } else {
        const child = spawnSync('supabase', [command], { stdio: 'inherit' });
        if (child.error) {
          process.stderr.write(`${child.error.message}\n`);
          process.exitCode = 1;
        } else {
          process.exitCode = child.status ?? 1;
        }
      }
    }
  }
}
