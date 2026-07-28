-- Planning et tâches quotidiennes.
CREATE INDEX IF NOT EXISTS idx_planning_employee_week_day
ON public.planning_templates (employee_id, numero_semaine, jour);

CREATE INDEX IF NOT EXISTS idx_taches_jour_employee_date_day
ON public.taches_jour (employee_id, semaine_reelle, jour);

CREATE INDEX IF NOT EXISTS idx_taches_jour_apartment_date
ON public.taches_jour (appartement_id, semaine_reelle);

CREATE INDEX IF NOT EXISTS idx_taches_jour_status_date
ON public.taches_jour (statut, semaine_reelle);

-- Disponibilités et présences.
CREATE INDEX IF NOT EXISTS idx_taches_disponibles_status_visibility
ON public.taches_disponibles (statut, visibilite, employee_visible_id);

CREATE INDEX IF NOT EXISTS idx_taches_disponibles_task
ON public.taches_disponibles (tache_jour_id);

CREATE INDEX IF NOT EXISTS idx_presences_date_status
ON public.presences (date, statut);

-- Notifications.
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread_date
ON public.notifications (destinataire_id, is_lue, date_envoi DESC);

CREATE INDEX IF NOT EXISTS idx_notifications_resident_unread_date
ON public.notifications_residents (resident_id, is_lue, date_envoi DESC);

-- Demandes et résidents.
CREATE INDEX IF NOT EXISTS idx_demandes_resident_date
ON public.demandes_residents (resident_id, date_creation DESC);

CREATE INDEX IF NOT EXISTS idx_demandes_resident_status_date
ON public.demandes_residents (statut, date_creation DESC);

CREATE INDEX IF NOT EXISTS idx_demandes_equipe_employee_date
ON public.demandes_equipe (employee_id, date_creation DESC);

CREATE INDEX IF NOT EXISTS idx_demandes_equipe_status_date
ON public.demandes_equipe (statut, date_creation DESC);

CREATE INDEX IF NOT EXISTS idx_residents_active_apartment
ON public.residents (appartement_id)
WHERE is_actif = true;

-- Communication et historique.
CREATE INDEX IF NOT EXISTS idx_chat_group_date
ON public.chat_groupe (date_envoi DESC)
WHERE is_supprimé = false;

CREATE INDEX IF NOT EXISTS idx_memos_employee_task_date
ON public.memos (employee_id, tache_jour_date DESC);

CREATE INDEX IF NOT EXISTS idx_historique_entity_date
ON public.historique_actions (entity_id, date_action DESC);

CREATE INDEX IF NOT EXISTS idx_transferts_task_date
ON public.transferts (tache_jour_id, date_transfert DESC);

CREATE INDEX IF NOT EXISTS idx_changements_task_date
ON public.changements_place (tache_jour_id, date_changement DESC);

-- Aires communes.
CREATE INDEX IF NOT EXISTS idx_aire_commune_week_status
ON public.taches_aire_commune (semaine_date, statut);
