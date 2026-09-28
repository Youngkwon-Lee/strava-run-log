import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import {
  EXPECTED_LINKED_PROJECT_REF,
  EXPECTED_LOCAL_PORTS,
  inspectSupabaseRouting
} from '../scripts/check_supabase_routing.mjs';

const configSource = readFileSync(new URL('../supabase/config.toml', import.meta.url), 'utf8');

test('Supabase local project and ports follow the repository routing contract', () => {
  const result = inspectSupabaseRouting({ configSource });
  assert.equal(result.ok, true, result.errors.join('\n'));
  assert.deepEqual(result.actual.ports, EXPECTED_LOCAL_PORTS);
});

test('Supabase routing rejects a link to another cloud project', () => {
  const result = inspectSupabaseRouting({
    configSource,
    linkedProjectRef: 'hcovmawjqteduykdnkwy'
  });
  assert.equal(result.ok, false);
  assert.match(result.errors.join('\n'), /linked project must be/);
  assert.equal(EXPECTED_LINKED_PROJECT_REF, 'iwtyzcwiovuvmsodtusx');
});
