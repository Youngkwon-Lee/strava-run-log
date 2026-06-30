update public.observations
set code_system = 'http://physiokorea.com/fhir/observation'
where code_system in ('physiokorea', 'internal');

update public.procedures
set code_system = 'http://physiokorea.com/fhir/observation'
where code_system in ('physiokorea', 'internal');;
