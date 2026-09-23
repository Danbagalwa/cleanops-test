-- ============================================================================
-- Côté RESPONSABLE : lire, répondre et résoudre les messages de la Réception
-- ============================================================================
-- CONTEXTE
--   Quand un résident appelle (« annuler mon ménage de jeudi »), la Réception ne
--   peut pas toucher au planning : elle transmet la demande au responsable
--   (table messages_reception, migrations 202609190021 et 202609210027). Le
--   responsable la lit dans « Demandes résidents », y répond et la résout. La
--   Réception voit le statut réel dans « Messages transmis ».
--
-- STATUTS (enum demande_statut) ET LEUR SENS
--   EnAttente : le responsable n'a encore rien fait.
--   Repondue  : le responsable a répondu, mais l'horaire n'a pas changé.
--   Resolue   : l'horaire a vraiment été modifié (le responsable le confirme par
--               un bouton, après avoir modifié le planning lui-même).
--
-- FONCTIONS (exécutables par anon et authenticated : l'application accède à la
-- base avec la clé publique)
--   responsable_messages_reception()
--       Tous les messages, les plus récents d'abord (300 au plus).
--   responsable_repondre_message_reception(message, auteur, reponse)
--       EnAttente -> Repondue ; permet aussi de MODIFIER une réponse déjà donnée.
--       Refusé si le message est déjà résolu. Réponse de 1 à 2000 caractères.
--   responsable_resoudre_message_reception(message, auteur)
--       EnAttente ou Repondue -> Resolue. Refusé si déjà résolu. Une réponse
--       écrite n'est pas obligatoire : modifier l'horaire suffit.
--   L'auteur doit être un employé ACTIF dont le rôle n'est ni Employé, ni
--   Résident, ni Reception (même définition que les destinataires des messages).
--
-- « HORAIRE MODIFIÉ » NE CONCERNE QUE LES DEMANDES D'HORAIRE
--   Une demande de nature « Autre » (clé perdue, information…) n'a pas d'horaire
--   à modifier : elle ne peut pas être marquée Résolue (refus avec un message
--   clair). Elle reste « Répondue » une fois traitée. Seules les demandes
--   d'Annulation et de Reprogrammation passent à Résolue.
--
-- NOTIFICATIONS DE LA RÉCEPTION
--   Chaque réponse et chaque résolution NOTIFIE l'AUTEUR du message (l'employé de
--   la Réception qui l'a envoyé), pour qu'il sache où en est la demande sans
--   rouvrir « Messages transmis ». Type MessageReception (déjà existant), texte :
--     « Réponse du responsable — Apt 101 : … »
--     « Demande résolue — Apt 101 : l'horaire a été modifié. »
--   Une notification qui échoue ne fait jamais échouer l'action (comportement de
--   app_notifier_employee).
--
-- TRACE : repondu_par / date_reponse (déjà présents), et resolu_par (ajouté ici) /
-- date_resolution (déjà présent).
--
-- NE FAIT PAS : ne modifie aucun planning ni aucune tâche. Le responsable le fait
-- lui-même, puis confirme par « Horaire modifié ».
--
-- ⚠ LIMITES
--   * L'auteur est un paramètre validé, pas authentifié (clé publique, sans
--     identité) ; sans RLS (report volontaire). Un appel direct avec la clé
--     publique peut aussi lire ou modifier messages_reception.
--   * La Réception n'est pas notifiée d'une réponse : elle consulte
--     « Messages transmis » (elle n'a pas accès aux notifications).
--   * Un message n'est relié à aucune tâche précise : « Résolue » repose sur le
--     clic du responsable, pas sur la détection d'un changement de planning.
--
-- POUR ANNULER :
--   DROP FUNCTION public.responsable_resoudre_message_reception(uuid, uuid);
--   DROP FUNCTION public.responsable_repondre_message_reception(uuid, uuid, text);
--   DROP FUNCTION public.responsable_messages_reception();
--   ALTER TABLE public.messages_reception DROP COLUMN resolu_par;
-- ============================================================================

ALTER TABLE public.messages_reception
  ADD COLUMN IF NOT EXISTS resolu_par uuid REFERENCES public.employees (id);

CREATE INDEX IF NOT EXISTS idx_messages_reception_resolu_par
  ON public.messages_reception (resolu_par) WHERE resolu_par IS NOT NULL;


-- ----------------------------------------------------------------------------
-- Lecture
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.responsable_messages_reception()
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
    LIMIT 300
  ) x;
$$;


-- ----------------------------------------------------------------------------
-- Répondre (ou modifier sa réponse)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.responsable_repondre_message_reception(
  p_message_id uuid,
  p_auteur_id uuid,
  p_reponse text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_rep text := btrim(coalesce(p_reponse, ''));
  v_statut text;
  v_auteur uuid;
  v_apt uuid;
  v_numero text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.employees
    WHERE id = p_auteur_id
      AND is_actif
      AND role::text NOT IN ('Employé', 'Résident', 'Resident', 'Reception')
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Auteur invalide ou inactif.';
  END IF;

  IF length(v_rep) < 1 OR length(v_rep) > 2000 THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'La réponse doit contenir entre 1 et 2000 caractères.';
  END IF;

  SELECT m.statut::text, m.auteur_id, m.appartement_id
  INTO v_statut, v_auteur, v_apt
  FROM public.messages_reception m
  WHERE m.id = p_message_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Message introuvable.';
  END IF;

  IF v_statut = 'Resolue' THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Ce message est déjà résolu.';
  END IF;

  UPDATE public.messages_reception
  SET statut = 'Repondue'::public.demande_statut,
      reponse = v_rep,
      repondu_par = p_auteur_id,
      date_reponse = now()
  WHERE id = p_message_id;

  -- Prévient l'auteur (Réception). Un échec de notification ne doit pas annuler
  -- la réponse.
  SELECT a.numero INTO v_numero FROM public.appartements a WHERE a.id = v_apt;
  PERFORM public.app_notifier_employee(
    v_auteur,
    'MessageReception',
    format('Réponse du responsable — Apt %s : %s',
           coalesce(v_numero, '?'), left(v_rep, 140))
      || CASE WHEN length(v_rep) > 140 THEN '…' ELSE '' END,
    v_apt,
    'Appartement'
  );

  RETURN jsonb_build_object('statut', 'Repondue');
END;
$$;


-- ----------------------------------------------------------------------------
-- Résoudre : l'horaire a vraiment été modifié
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.responsable_resoudre_message_reception(
  p_message_id uuid,
  p_auteur_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_statut text;
  v_nature text;
  v_auteur uuid;
  v_apt uuid;
  v_numero text;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.employees
    WHERE id = p_auteur_id
      AND is_actif
      AND role::text NOT IN ('Employé', 'Résident', 'Resident', 'Reception')
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Auteur invalide ou inactif.';
  END IF;

  SELECT m.statut::text, m.nature, m.auteur_id, m.appartement_id
  INTO v_statut, v_nature, v_auteur, v_apt
  FROM public.messages_reception m
  WHERE m.id = p_message_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Message introuvable.';
  END IF;

  IF v_statut = 'Resolue' THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Ce message est déjà résolu.';
  END IF;

  -- « Horaire modifié » n'a de sens que pour une annulation ou une
  -- reprogrammation.
  IF v_nature NOT IN ('Annulation', 'Reprogrammation') THEN
    RAISE EXCEPTION USING ERRCODE = 'P0001',
      MESSAGE = 'Cette demande ne concerne pas l''horaire : répondez-y simplement.';
  END IF;

  UPDATE public.messages_reception
  SET statut = 'Resolue'::public.demande_statut,
      date_resolution = now(),
      resolu_par = p_auteur_id
  WHERE id = p_message_id;

  -- Prévient l'auteur (Réception). Un échec de notification ne doit pas annuler
  -- la résolution.
  SELECT a.numero INTO v_numero FROM public.appartements a WHERE a.id = v_apt;
  PERFORM public.app_notifier_employee(
    v_auteur,
    'MessageReception',
    format('Demande résolue — Apt %s : l''horaire a été modifié.',
           coalesce(v_numero, '?')),
    v_apt,
    'Appartement'
  );

  RETURN jsonb_build_object('statut', 'Resolue');
END;
$$;


-- ----------------------------------------------------------------------------
-- Droits
-- ----------------------------------------------------------------------------
REVOKE ALL ON FUNCTION public.responsable_messages_reception() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.responsable_repondre_message_reception(uuid, uuid, text)
  FROM PUBLIC;
REVOKE ALL ON FUNCTION public.responsable_resoudre_message_reception(uuid, uuid)
  FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.responsable_messages_reception()
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.responsable_repondre_message_reception(uuid, uuid, text)
  TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.responsable_resoudre_message_reception(uuid, uuid)
  TO anon, authenticated;
