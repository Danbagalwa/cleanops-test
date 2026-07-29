-- Active la diffusion des changements INSERT/UPDATE/DELETE de la table
-- notifications vers les clients abonnés Supabase Realtime.
DO $$
BEGIN
  ALTER PUBLICATION supabase_realtime
    ADD TABLE public.notifications;
EXCEPTION
  WHEN duplicate_object THEN
    NULL;
END
$$;
