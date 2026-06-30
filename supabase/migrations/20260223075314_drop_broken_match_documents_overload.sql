-- Drop the broken overload that references non-existent mvp_vector_search table
DROP FUNCTION IF EXISTS public.match_documents(vector, double precision, integer, text, text);;
