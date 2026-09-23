-- ============================================================================
-- Messages de la Réception : « nature de la demande »
-- ============================================================================
-- CONTEXTE
--   Un résident appelle la Réception (« annuler mon ménage de jeudi »,
--   « repousser à l'après-midi »). La Réception ne peut pas toucher au planning :
--   elle transmet la demande depuis la fiche de l'appartement. Le formulaire doit
--   donc préciser la NATURE de la demande, en plus du texte libre et de la case
--   « Transmettre aussi à l'employé ».
--
-- CE QUE FAIT CETTE MIGRATION
--   1. messages_reception.nature : Annulation · Reprogrammation · Autre.
--      Les messages déjà envoyés prennent « Autre » (valeur par défaut).
--   2. reception_envoyer_message(...) reçoit p_nature (défaut « Autre », donc un
--      client plus ancien qui n'envoie pas la nature continue de fonctionner).
--      Le texte de la notification indique la nature. Corps repris de
--      202609190021 (déjà testé) ; seuls la nature et le texte changent.
--   3. reception_messages_transmis() renvoie aussi « nature ».
--
-- STATUTS (inchangés) : EnAttente, Repondue, Resolue.
--   En attente = personne n'a encore traité la demande ; Répondue = une réponse
--   a été donnée mais l'horaire n'a pas changé ; Résolue = l'horaire a été
--   modifié. Aucune fonction ne fait encore passer un message à Répondue ou
--   Résolue : l'écran qui les traite côté responsable n'est pas construit.
--
-- POUR ANNULER (la colonne peut rester ; remettre l'ancienne fonction d'envoi
-- exige de ré-appliquer 202609190021 et 202609210026) :
--   ALTER TABLE public.messages_reception DROP COLUMN nature;
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 1. Colonne
-- ----------------------------------------------------------------------------
ALTER TABLE public.messages_reception
  ADD COLUMN IF NOT EXISTS nature text NOT NULL DEFAULT 'Autre';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'messages_reception_nature'
      AND conrelid = 'public.messages_reception'::regclass
  ) THEN
    ALTER TABLE public.messages_reception
      ADD CONSTRAINT messages_reception_nature
      CHECK (nature IN ('Annulation', 'Reprogrammation', 'Autre'));
  END IF;
END
$$;


-- ----------------------------------------------------------------------------
-- 2. Envoi (nouvelle signature : on retire l'ancienne pour éviter toute
--    ambiguïté d'appel)
-- ----------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.reception_envoyer_message(uuid, uuid, text, boolean);

CREATE OR REPLACE FUNCTION public.reception_envoyer_message(
  p_appartement_id uuid,
  p_auteur_id uuid,
  p_message text,
  p_transmettre_employe boolean DEFAULT false,
  p_nature text DEFAULT 'Autre'
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_msg text := btrim(coalesce(p_message, ''));
  v_nature text := coalesce(p_nature, 'Autre');
  v_numero text;
  v_emp uuid;
  v_id uuid;
  v_dest record;
  v_texte text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.employees
    WHERE id = p_auteur_id AND is_actif AND role::text = 'Reception'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Auteur invalide ou inactif.';
  END IF;

  IF v_nature NOT IN ('Annulation', 'Reprogrammation', 'Autre') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Nature de la demande invalide.';
  END IF;

  SELECT a.numero INTO v_numero
  FROM public.appartements a
  WHERE a.id = p_appartement_id AND a.type::text = 'Appartement';

  IF v_numero IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Appartement introuvable.';
  END IF;

  IF length(v_msg) < 1 OR length(v_msg) > 2000 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Le message doit contenir entre 1 et 2000 caractères.';
  END IF;

  IF coalesce(p_transmettre_employe, false) THEN
    SELECT c.o_id INTO v_emp
    FROM public.reception_employe_concerne(p_appartement_id) c;

    IF v_emp IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'P0001',
        MESSAGE = 'Aucun employé n''est concerné par cet appartement.';
    END IF;
  END IF;

  INSERT INTO public.messages_reception
    (appartement_id, auteur_id, message, transmettre_employe, employee_id, nature)
  VALUES
    (p_appartement_id, p_auteur_id, v_msg,
     coalesce(p_transmettre_employe, false), v_emp, v_nature)
  RETURNING id INTO v_id;

  v_texte := format('Message de la réception — Apt %s · %s : %s',
                    v_numero,
                    CASE v_nature
                      WHEN 'Annulation' THEN 'annulation'
                      WHEN 'Reprogrammation' THEN 'reprogrammation'
                      ELSE 'autre demande'
                    END,
                    left(v_msg, 140))
             || CASE WHEN length(v_msg) > 140 THEN '…' ELSE '' END;

  FOR v_dest IN
    SELECT e.id
    FROM public.employees e
    WHERE e.is_actif
      AND e.role::text NOT IN ('Employé', 'Résident', 'Resident', 'Reception')
  LOOP
    PERFORM public.app_notifier_employee(
      v_dest.id, 'MessageReception', v_texte, p_appartement_id, 'Appartement'
    );
  END LOOP;

  IF v_emp IS NOT NULL THEN
    PERFORM public.app_notifier_employee(
      v_emp, 'MessageReception', v_texte, p_appartement_id, 'Appartement'
    );
  END IF;

  RETURN v_id;
END;
$$;

REVOKE ALL ON FUNCTION public.reception_envoyer_message(uuid, uuid, text, boolean, text)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reception_envoyer_message(uuid, uuid, text, boolean, text)
  TO anon, authenticated;


-- ----------------------------------------------------------------------------
-- 3. Lecture : ajoute « nature » (reste de la fonction inchangé, 202609210026)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reception_messages_transmis()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, extensions
AS $$
  SELECT coalesce(jsonb_agg(x.item ORDER BY x.cree DESC), '[]'::jsonb)
  FROM (
    SELECT
      m.date_creation AS cree,
      jsonb_build_object(
        'id', m.id,
        'appartement_id', a.id,
        'numero', a.numero,
        'nature', m.nature,
        'message', m.message,
        'auteur_prenom', au.prenom,
        'transmis_employe', m.transmettre_employe,
        'employe_prenom',
          CASE WHEN m.transmettre_employe THEN em.prenom END,
        'statut', m.statut::text,
        'reponse', m.reponse,
        'date_creation',
          to_char(m.date_creation AT TIME ZONE 'America/Toronto',
                  'YYYY-MM-DD"T"HH24:MI:SS'),
        'date_reponse',
          to_char(m.date_reponse AT TIME ZONE 'America/Toronto',
                  'YYYY-MM-DD"T"HH24:MI:SS'),
        'date_resolution',
          to_char(m.date_resolution AT TIME ZONE 'America/Toronto',
                  'YYYY-MM-DD"T"HH24:MI:SS')
      ) AS item
    FROM public.messages_reception m
    JOIN public.appartements a ON a.id = m.appartement_id
    JOIN public.employees au ON au.id = m.auteur_id
    LEFT JOIN public.employees em ON em.id = m.employee_id
    ORDER BY m.date_creation DESC
    LIMIT 200
  ) x;
$$;

REVOKE ALL ON FUNCTION public.reception_messages_transmis() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reception_messages_transmis()
  TO anon, authenticated;
