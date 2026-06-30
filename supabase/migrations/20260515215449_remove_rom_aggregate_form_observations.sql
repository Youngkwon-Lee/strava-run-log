-- ROM form responses should project atomic movement measurements, not an
-- aggregate instrument score. The previous projector revision briefly created
-- aggregate rows such as code=ROM_KNEE for rows with total_score.

delete from public.observations
where source_type = 'form'
  and form_response_id is not null
  and code like 'ROM\_%' escape '\'
  and measurement_context ->> 'is_aggregate' = 'true';
