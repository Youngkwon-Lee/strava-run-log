-- Formalize pose snapshot storage in encounter_media.
-- Application capture flows may still emit media_type='pose_snapshot',
-- but persisted rows should be stored as:
--   media_type='photo'
--   media_subtype='pose_snapshot'
--   metadata.capture_modality='pose_snapshot'

update public.encounter_media
set
  media_type = 'photo',
  media_subtype = 'pose_snapshot',
  metadata = jsonb_set(
    coalesce(metadata, '{}'::jsonb),
    '{capture_modality}',
    to_jsonb('pose_snapshot'::text),
    true
  )
where media_type = 'pose_snapshot';
update public.encounter_media
set
  media_subtype = 'pose_snapshot',
  metadata = jsonb_set(
    coalesce(metadata, '{}'::jsonb),
    '{capture_modality}',
    to_jsonb('pose_snapshot'::text),
    true
  )
where media_type = 'photo'
  and media_subtype is distinct from 'pose_snapshot'
  and (
    coalesce(metadata->>'capture_modality', '') = 'pose_snapshot'
    or jsonb_typeof(coalesce(metadata, '{}'::jsonb)->'pose_snapshot') = 'object'
  );
alter table public.encounter_media
  drop constraint if exists encounter_media_pose_snapshot_storage_check;
alter table public.encounter_media
  add constraint encounter_media_pose_snapshot_storage_check
  check (
    media_subtype is distinct from 'pose_snapshot'
    or (
      media_type = 'photo'
      and (
        coalesce(metadata->>'capture_modality', '') = 'pose_snapshot'
        or coalesce(jsonb_typeof(coalesce(metadata, '{}'::jsonb)->'pose_snapshot'), '') = 'object'
      )
    )
  );
