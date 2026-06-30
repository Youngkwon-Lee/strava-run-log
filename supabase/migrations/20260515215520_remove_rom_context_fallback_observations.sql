-- body_part inside ROM responses is context for the movement measurement,
-- not its own observation value.

delete from public.observations
where source_type = 'form'
  and form_response_id is not null
  and code like 'ROM\_%_body_part' escape '\'
  and measurement_context ->> 'projector' = 'assessment_form_response_to_observation_v1';
