-- P1 follow-up: add covering index for voice_memos foreign key.

create index if not exists idx_voice_memos_provider_person_id
  on public.voice_memos (provider_person_id);
