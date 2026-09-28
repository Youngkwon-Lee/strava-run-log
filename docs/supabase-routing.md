# Supabase routing contract

This repository is a PGHD/run-log client of the Kinelo product database. It is
not the owner of the product-wide migration history.

## Project identities

| Use | Identity | Rule |
| --- | --- | --- |
| Local Docker stack | `project_id = "strava-run-log"` | Use ports `54340-54349`; never reuse the `kinelo-ops` or `physio_app` blocks. |
| Product production | `iwtyzcwiovuvmsodtusx` | This is the only allowed `supabase link` target for the guarded PGHD production checks in this repository. |
| Product staging | `hcovmawjqteduykdnkwy` | Use from the owning `physio_app` workflow for ordinary staging QA; do not relink this checkout casually. |
| Kinelo operations | `oqqriuozgiegqqnutnnd` | Never target from this repository. |
| Legacy PhysioKorea | `jujjperigvwygarwpwdn` | Never target from this repository. |

Project refs are identifiers, not secrets. Keys, tokens, database passwords,
and connection strings must stay in ignored local files or a secret manager.

## Which environment to use

- Use the local stack for migration rehearsal, RLS/Auth behavior, destructive
  fixtures, and offline development. Start it with
  `node scripts/check_supabase_routing.mjs start`; this runs the routing check
  first.
- Use product staging through the `physio_app`-owned staging workflow for normal
  integration and human QA.
- Use the linked production project only for the existing guarded read/status,
  smoke, or explicitly approved apply paths documented in the README. A plain
  broad `supabase db push --linked` remains forbidden here.
- A cloud preview branch is appropriate when an isolated, shareable database is
  worth the extra hosted cost. It does not replace the stable staging project or
  the local migration/RLS rehearsal loop.
- GitHub-hosted Linux can run a temporary local Supabase stack for repeatable DB
  CI. Add that only through a reviewed CI change; it is not required for normal
  local work.

## Local lifecycle

```bash
node scripts/check_supabase_routing.mjs
node scripts/check_supabase_routing.mjs start
node scripts/check_supabase_routing.mjs status
node scripts/check_supabase_routing.mjs stop
```

The reserved local ports are API `54341`, database `54342`, shadow database
`54340`, Studio `54343`, Inbucket `54344`, analytics `54347`, and pooler
`54349`. Optional SMTP/POP3 ports, if enabled, are `54345`/`54346`.

The routing check also validates `supabase/.temp/project-ref` when the checkout
has been linked. An absent link is allowed for local-only development; a link to
any project other than product production fails.

Before a remote operation, run the routing check and inspect the exact command.
Do not infer the target from the repository name or from an environment file in
another checkout.
