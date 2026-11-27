# Planning de service

Application web installable (PWA) pour le planning de service d'anesthésie-réanimation : bloc, consultation, SSPI, gardes, repos de garde, congés.

- `index.html` : l'appli (un seul fichier). Sans clés Supabase, elle fonctionne en mode local sur l'appareil.
- `supabase-setup.sql` : base, droits et historique, à coller une fois dans Supabase.
- `MISE-EN-PLACE.md` : guide de mise en service.
- `deploy/build.py` : ajoute la Project URL, la clé anon et la politique de sécurité (CSP) pour la version en ligne.

Ne jamais mettre la clé `service_role` dans ce dépôt.
