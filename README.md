# Planning de service

Application web installable (PWA) pour le planning de service d'anesthésie-réanimation : bloc, consultation, SSPI, gardes, repos de garde, congés.

- `index.html` : l'appli (un seul fichier), branchée sur la base Supabase du service (Project URL + clé publishable, faites pour être publiques).
- `supabase-setup.sql` : base, droits et historique, à coller une fois dans Supabase.
- `MISE-EN-PLACE.md` : guide de mise en service.
- `deploy/build.py` : refabrique `index.html` depuis la version source (CFG vide) avec la Project URL, la clé publishable et la CSP.

Ne jamais mettre la clé `service_role` dans ce dépôt.
