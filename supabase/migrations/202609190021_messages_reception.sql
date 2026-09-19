-- ============================================================================
-- Messages de la Réception vers l'administration (table + fonction d'envoi)
-- ============================================================================
-- OBJECTIF
--   Depuis la fiche d'un appartement, la Réception transmet un message à
--   l'administration, avec une case facultative « Transmettre aussi à
--   l'employé ». La section « Messages transmis » (autre chantier) listera ces
--   messages avec leur statut.
--
-- STATUTS : En attente · Répondue · Résolue
--   Réutilise l'enum demande_statut (EnAttente, Repondue, Resolue), déjà utilisé
--   par les demandes des résidents et de l'équipe. Aucun statut « Traitée ».
--
-- FONCTION reception_envoyer_message(appartement, auteur, message, transmettre)
--   * L'auteur doit être un employé ACTIF de rôle 'Reception' ;
--   * le message est nettoyé (btrim) et doit faire de 1 à 2000 caractères ;
--   * l'appartement doit exister (type 'Appartement') ;
--   * si « transmettre » : l'employé visé est celui que renvoie
--     reception_employe_concerne (tâche du jour non libérée, sinon prochaine
--     date connue). S'il n'y en a aucun, l'envoi est REFUSÉ avec un message
--     clair plutôt que d'ignorer la case en silence.
--   * Notifications (type MessageReception, migration 202609190019) :
--       - à chaque administrateur actif : Admin, Direction, SuperviseurMenage
--         et le rôle historique Employeur (tout rôle sauf Employé, Résident et
--         Reception) ;
--       - à l'employé visé si la case est cochée.
--     Une notification qui échoue ne fait JAMAIS échouer l'envoi : le message
--     est enregistré d'abord (comportement de app_notifier_employee).
--
-- ⚠ LIMITES
--   * Le serveur ne connaît pas l'utilisateur connecté (l'application utilise la
--     clé publique, sans identité) : l'auteur est un paramètre. Il est validé
--     (actif, rôle Reception) mais pas authentifié. Le chantier RLS / sessions
--     doit le remplacer par une identité serveur.
--   * Comme les autres tables, messages_reception est sans RLS pour l'instant
--     (report volontaire) : lisible et modifiable avec la clé publique.
--   * La liste des destinataires administrateurs est définie par exclusion :
--     un futur rôle serait notifié par défaut (voir 202609190015).
--   * app_notifier_employee ignore une notification identique reçue par le même
--     destinataire pour le même appartement dans les 10 dernières secondes : le
--     message reste enregistré, seule la notification est omise.
--
-- POUR ANNULER :
--   DROP FUNCTION public.reception_envoyer_message(uuid, uuid, text, boolean);
--   DROP TABLE public.messages_reception;
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.messages_reception (
  id uuid PRIMARY KEY DEFAULT extensions.uuid_generate_v4(),
  appartement_id uuid NOT NULL REFERENCES public.appartements (id),
  auteur_id uuid NOT NULL REFERENCES public.employees (id),
  message text NOT NULL
    CONSTRAINT messages_reception_message_longueur
    CHECK (length(btrim(message)) BETWEEN 1 AND 2000),
  transmettre_employe boolean NOT NULL DEFAULT false,
  employee_id uuid REFERENCES public.employees (id),
  statut public.demande_statut NOT NULL DEFAULT 'EnAttente',
  reponse text,
  repondu_par uuid REFERENCES public.employees (id),
  date_creation timestamptz NOT NULL DEFAULT now(),
  date_reponse timestamptz,
  date_resolution timestamptz,
  CONSTRAINT messages_reception_employe_si_transmis
    CHECK (NOT transmettre_employe OR employee_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_messages_reception_auteur_date
  ON public.messages_reception (auteur_id, date_creation DESC);
CREATE INDEX IF NOT EXISTS idx_messages_reception_statut_date
  ON public.messages_reception (statut, date_creation DESC);
CREATE INDEX IF NOT EXISTS idx_messages_reception_appartement
  ON public.messages_reception (appartement_id);
CREATE INDEX IF NOT EXISTS idx_messages_reception_employee
  ON public.messages_reception (employee_id) WHERE employee_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_messages_reception_repondu_par
  ON public.messages_reception (repondu_par) WHERE repondu_par IS NOT NULL;


CREATE OR REPLACE FUNCTION public.reception_envoyer_message(
  p_appartement_id uuid,
  p_auteur_id uuid,
  p_message text,
  p_transmettre_employe boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_msg text := btrim(coalesce(p_message, ''));
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
    (appartement_id, auteur_id, message, transmettre_employe, employee_id)
  VALUES
    (p_appartement_id, p_auteur_id, v_msg,
     coalesce(p_transmettre_employe, false), v_emp)
  RETURNING id INTO v_id;

  v_texte := format('Message de la réception — Apt %s : %s',
                    v_numero, left(v_msg, 140))
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

REVOKE ALL ON FUNCTION public.reception_envoyer_message(uuid, uuid, text, boolean)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reception_envoyer_message(uuid, uuid, text, boolean)
  TO anon, authenticated;
