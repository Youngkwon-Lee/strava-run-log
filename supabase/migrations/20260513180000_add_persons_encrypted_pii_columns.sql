-- Purpose:
--   Add additive app-level encryption columns for the first selective PII rollout.
--
-- Scope:
--   public.persons
--
-- Phase:
--   additive only (no legacy plaintext removal yet)

ALTER TABLE public.persons
  ADD COLUMN IF NOT EXISTS email_enc text,
  ADD COLUMN IF NOT EXISTS email_enc_iv text,
  ADD COLUMN IF NOT EXISTS email_enc_tag text,
  ADD COLUMN IF NOT EXISTS email_lookup_hash text,
  ADD COLUMN IF NOT EXISTS email_key_version smallint,
  ADD COLUMN IF NOT EXISTS phone_enc text,
  ADD COLUMN IF NOT EXISTS phone_enc_iv text,
  ADD COLUMN IF NOT EXISTS phone_enc_tag text,
  ADD COLUMN IF NOT EXISTS phone_lookup_hash text,
  ADD COLUMN IF NOT EXISTS phone_key_version smallint,
  ADD COLUMN IF NOT EXISTS address_enc text,
  ADD COLUMN IF NOT EXISTS address_enc_iv text,
  ADD COLUMN IF NOT EXISTS address_enc_tag text,
  ADD COLUMN IF NOT EXISTS address_key_version smallint,
  ADD COLUMN IF NOT EXISTS emergency_contact_enc text,
  ADD COLUMN IF NOT EXISTS emergency_contact_enc_iv text,
  ADD COLUMN IF NOT EXISTS emergency_contact_enc_tag text,
  ADD COLUMN IF NOT EXISTS emergency_contact_key_version smallint;
CREATE INDEX IF NOT EXISTS idx_persons_email_lookup_hash
  ON public.persons (email_lookup_hash)
  WHERE email_lookup_hash IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_persons_phone_lookup_hash
  ON public.persons (phone_lookup_hash)
  WHERE phone_lookup_hash IS NOT NULL;
COMMENT ON COLUMN public.persons.email_enc IS 'AES-256-GCM ciphertext for email (app-level encryption)';
COMMENT ON COLUMN public.persons.email_lookup_hash IS 'HMAC lookup hash for normalized email exact-match queries';
COMMENT ON COLUMN public.persons.phone_enc IS 'AES-256-GCM ciphertext for phone (app-level encryption)';
COMMENT ON COLUMN public.persons.phone_lookup_hash IS 'HMAC lookup hash for normalized phone exact-match queries';
COMMENT ON COLUMN public.persons.address_enc IS 'AES-256-GCM ciphertext for address (app-level encryption)';
COMMENT ON COLUMN public.persons.emergency_contact_enc IS 'AES-256-GCM ciphertext for emergency_contact json payload';
