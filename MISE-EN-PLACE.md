# Planning de service : mise en service pour décembre

Il faut compter environ 45 minutes de votre côté, en 4 étapes. Dites-moi quand les étapes 1 et 2 sont faites : je m'occupe ensuite de la mise en ligne.

## 1. Créer la base Supabase (environ 15 min, sur ordinateur)
1. Allez sur supabase.com, puis **Start your project**. Créez un compte, par exemple avec votre compte GitHub.
2. Cliquez sur **New project** et renseignez :
   - le nom : `planning-service` ;
   - le mot de passe de la base : choisissez-en un long et gardez-le pour vous, je n'en ai pas besoin ;
   - la région : **West EU (Paris)** (ou Frankfurt), pour que les données restent dans l'UE.
3. Une fois le projet prêt, ouvrez **SQL Editor > New query**. Collez tout le fichier `supabase-setup.sql`, puis cliquez sur **Run**. Vous devez voir « Success ».
4. Dans **Authentication > Sign In / Providers > Email** :
   - désactivez « Allow new users to sign up », pour que seuls les comptes que vous créez existent ;
   - réglez « Minimum password length » sur **10**.
5. Créez votre propre compte : **Authentication > Users > Add user > Create new user**. Indiquez votre e-mail et un mot de passe, puis cochez « Auto Confirm User ».
6. Revenez dans **SQL Editor** et exécutez la ligne suivante, avec votre adresse e-mail et votre nom. Elle fait de vous l'administrateur :
   ```sql
   update public.profiles set role = 'admin', active = true, display_name = 'Votre nom'
   where email = 'votre.adresse@exemple.fr';
   ```
7. Ouvrez **Project Settings > API** (ou **API Keys**) et envoyez-moi :
   - la **Project URL**, de la forme `https://xxxx.supabase.co` ;
   - la clé **anon / publishable**.

   Ne m'envoyez jamais la clé `service_role` / `secret`, ni le mot de passe de la base.

## 2. GitHub (5 min)
Il faut un dépôt `planning-service` sur votre compte GitHub. Je peux le créer pour vous si vous me donnez votre accord, ou vous pouvez le créer vous-même : bouton **New repository**, nom `planning-service`, sans autre option.

Ensuite, je dépose l'appli dans le dépôt. Il vous restera à :
1. passer le dépôt en **Public** : Settings > General > Danger Zone > Change visibility. L'hébergement gratuit (GitHub Pages) l'exige. Le code ne contient aucune donnée ni aucun secret : la clé « anon » est faite pour être publique, et la sécurité repose sur les comptes et les règles de la base ;
2. ouvrir **Settings > Pages**, puis choisir Source : **Deploy from a branch**, Branch : **main**, dossier **/ (root)**, et cliquer sur **Save**.

L'adresse de l'appli sera `https://<votre-identifiant>.github.io/planning-service/`.

Enfin, dans Supabase, ouvrez **Authentication > URL Configuration** et collez cette adresse dans « Site URL ».

## 3. Préparer décembre dans l'appli (environ 20 min)
1. Ouvrez l'adresse de l'appli et connectez-vous. Au premier passage, l'appli vous demande un nouveau mot de passe.
2. Dans **Réglages › Équipe**, ajoutez-vous, puis ajoutez chaque médecin avec sa quotité (100 %, 80 %, 50 %…).
3. Dans **Réglages › Comptes**, reliez votre compte à votre ligne.
4. Vérifiez les réglages suivants :
   - **Réglages › Bloc** : 1 anesthésiste par jour, Endoscopie 1 ouverte ;
   - **Postes et besoins** : les heures, les horaires et les besoins (gardes GM et GU, consultation).
5. Saisissez ou faites saisir les gardes, la SSPI, les DIVLD et les congés de décembre.
6. Dans **Équipe**, passez en vue Mois sur décembre, puis appuyez sur **Répartir bloc et consultation**. Contrôlez le résultat : le bouton Annuler reste disponible.

## 4. Ajouter les collègues
Pour chaque collègue :
1. Dans Supabase, ouvrez **Authentication > Users > Add user**. Indiquez son e-mail et un mot de passe initial aléatoire de 12 caractères ou plus, puis cochez « Auto Confirm User ».
2. Dans l'appli, ouvrez **Réglages › Comptes**, cochez « Activé » et choisissez **sa ligne**.
3. Envoyez-lui l'adresse de l'appli et son identifiant, puis le mot de passe **par un autre canal**, par exemple par SMS. À sa première connexion, l'appli lui demande d'en choisir un nouveau.

## Secrétaires et intérimaires
- **Secrétaire** : créez son compte comme pour un médecin, puis dans **Comptes** cochez « Activé », choisissez le rôle **Secrétaire** et ne lui attribuez aucune ligne. Elle voit tout le planning (Mon planning › « changer » pour afficher celui d'un médecin) et ne peut modifier que les lignes d'intérimaires.
- **Intérimaire** : dans **Réglages › Équipe**, ajoutez une ligne (par exemple « Intérim 1 ») et cochez **Intérim**. Elle ne demande pas de compte, n'entre ni dans la répartition automatique ni dans l'équilibre sur 3 mois. Vous ou la secrétaire y placez les jours de remplacement.

## Installer l'appli sur le téléphone
- **iPhone** : ouvrez l'adresse dans Safari, puis Partager > « Sur l'écran d'accueil ».
- **Android** : ouvrez l'adresse dans Chrome, puis menu ⋮ > « Installer l'application ».

## Au quotidien
- **Départ d'un médecin** : dans **Comptes**, décochez « Activé ». L'accès est coupé tout de suite.
- **Mot de passe oublié** : dans Supabase, ouvrez **Authentication > Users**, choisissez son compte et définissez un mot de passe provisoire. Puis, dans Table Editor > `profiles`, remettez `must_change_pw` à `true`.

## Droits
- **Administrateur (vous)** : gère l'équipe, les quotités, les postes, les salles, les seuils et les comptes. Lui seul lance la répartition du bloc et de la consultation.
- **Praticien activé** : saisit uniquement sur **sa ligne** ses gardes, SSPI, DIVLD, TNC, réunions, vacances et indisponibilités. Il ne peut modifier ni le bloc ou la consultation posés par l'administrateur, ni la ligne d'un collègue : c'est le serveur qui le contrôle. Chaque modification est tracée.
- **Compte non activé** : aucun accès.

## Points à garder en tête
- Ne saisissez aucune donnée patient : l'appli ne sert qu'au planning, et l'hébergement n'est pas certifié HDS.
- Il est conseillé de prévenir le DPO de l'établissement : l'appli stocke les noms et e-mails des médecins, chez Supabase, dans l'UE.
- L'offre gratuite de Supabase met le projet en pause après 7 jours sans aucune connexion. Il suffit de le relancer depuis le tableau de bord ; avec un usage quotidien, cela n'arrive pas.
