-- Planning de service : installation de la base Supabase (version 3)
-- À coller dans Supabase > SQL Editor > New query, puis « Run ». Une seule fois.
-- Droits : l'administrateur gère l'équipe, les postes, les quotités, les comptes et le bloc/consultation ;
-- un praticien ACTIVÉ ne saisit que SA ligne, et seulement les postes non répartis automatiquement
-- (gardes, SSPI, DIVLD, vacances, indisponibilités…) ; chaque modification est historisée.

-- 1. Profils : un par compte
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text not null default '',
  display_name text not null default '' check (char_length(display_name) <= 60),
  role text not null default 'member' check (role in ('admin','member')),
  active boolean not null default false,          -- l'admin active chaque compte
  must_change_pw boolean not null default true,
  prefs jsonb not null default '{}'::jsonb check (pg_column_size(prefs) < 20000),
  doc_id text,                                    -- ligne du planning reliée à ce compte (fixée par l'admin)
  created_at timestamptz not null default now()
);

-- 2. Configuration du service (équipe, postes, seuils) : un seul document, modifiable par l'admin
create table if not exists public.service_state (
  id int primary key default 1 check (id = 1),
  data jsonb not null default '{}'::jsonb check (pg_column_size(data) < 500000),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);
insert into public.service_state (id) values (1) on conflict do nothing;
alter table public.profiles add column if not exists doc_id text;

-- 3. Cases du planning : une ligne par médecin et par jour
create table if not exists public.assignments (
  day date not null,
  doc_id text not null check (char_length(doc_id) between 1 and 40),
  post_id text not null check (char_length(post_id) between 1 and 40),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  primary key (day, doc_id)
);

-- 4. Historique des modifications (lecture seule pour tous)
create table if not exists public.assignment_log (
  id bigserial primary key,
  day date not null,
  doc_id text not null,
  old_post text,
  new_post text,
  changed_by uuid,
  changed_by_name text,
  changed_at timestamptz not null default now()
);
create index if not exists assignment_log_day on public.assignment_log (day, changed_at desc);

-- 5. Fonctions d'autorisation
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'admin' and active);
$$;
create or replace function public.is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and active);
$$;

-- 6. Profil créé automatiquement à la création d'un compte (inactif par défaut)
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, display_name)
  values (new.id, coalesce(new.email,''), split_part(coalesce(new.email,''), '@', 1))
  on conflict do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- 7. Un non-admin ne peut changer ni son rôle, ni son activation, ni son e-mail
create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null and not public.is_admin() then
    new.role := old.role; new.active := old.active; new.email := old.email; new.id := old.id; new.doc_id := old.doc_id;
  end if;
  return new;
end $$;
drop trigger if exists guard_profile on public.profiles;
create trigger guard_profile before update on public.profiles
  for each row execute function public.guard_profile();

-- 7b. Ligne du praticien connecté, et parties « automatiques » (bloc/consultation) d'une case
create or replace function public.my_doc() returns text
language sql stable security definer set search_path = public as $$
  select doc_id from public.profiles where id = auth.uid();
$$;
create or replace function public.auto_parts(v text) returns text
language sql stable security definer set search_path = public as $$
  select coalesce(string_agg(x, '+' order by x), '')
  from unnest(string_to_array(coalesce(v, ''), '+')) as x
  where exists (select 1 from public.service_state s, jsonb_array_elements(coalesce(s.data->'posts','[]'::jsonb)) p
                where p->>'id' = x and coalesce((p->>'auto')::boolean, false));
$$;

-- 7c. Un praticien ne modifie que sa ligne, et jamais le bloc/consultation posé par l'admin
create or replace function public.guard_assignment() returns trigger
language plpgsql security definer set search_path = public as $$
declare prev text; mine text;
begin
  if auth.uid() is null or public.is_admin() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  mine := public.my_doc();
  if tg_op = 'DELETE' then
    if mine is null or old.doc_id is distinct from mine then raise exception 'Vous ne pouvez modifier que votre ligne'; end if;
    if public.auto_parts(old.post_id) <> '' then raise exception 'Le bloc et la consultation sont gérés par l''administrateur'; end if;
    return old;
  end if;
  if mine is null or new.doc_id is distinct from mine then raise exception 'Vous ne pouvez modifier que votre ligne'; end if;
  if tg_op = 'UPDATE' and (new.day <> old.day or new.doc_id <> old.doc_id) then raise exception 'Modification interdite'; end if;
  select post_id into prev from public.assignments where day = new.day and doc_id = new.doc_id;
  if public.auto_parts(new.post_id) <> public.auto_parts(prev) then
    raise exception 'Le bloc et la consultation sont gérés par l''administrateur';
  end if;
  return new;
end $$;
drop trigger if exists guard_assignment on public.assignments;
create trigger guard_assignment before insert or update or delete on public.assignments
  for each row execute function public.guard_assignment();

-- 8. Auteur et date d'une case toujours fixés par le serveur
create or replace function public.stamp_assignment() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  new.updated_by := auth.uid(); new.updated_at := now();
  return new;
end $$;
drop trigger if exists stamp_assignment on public.assignments;
create trigger stamp_assignment before insert or update on public.assignments
  for each row execute function public.stamp_assignment();

create or replace function public.log_assignment() returns trigger
language plpgsql security definer set search_path = public as $$
declare n text;
begin
  select coalesce(nullif(display_name,''), email) into n from public.profiles where id = auth.uid();
  if tg_op = 'DELETE' then
    insert into public.assignment_log (day, doc_id, old_post, new_post, changed_by, changed_by_name)
    values (old.day, old.doc_id, old.post_id, null, auth.uid(), n);
    return old;
  elsif tg_op = 'UPDATE' and old.post_id is not distinct from new.post_id then
    return new;
  else
    insert into public.assignment_log (day, doc_id, old_post, new_post, changed_by, changed_by_name)
    values (new.day, new.doc_id, case when tg_op = 'UPDATE' then old.post_id end, new.post_id, auth.uid(), n);
    return new;
  end if;
end $$;
drop trigger if exists log_assignment on public.assignments;
create trigger log_assignment after insert or update or delete on public.assignments
  for each row execute function public.log_assignment();

-- 9. Sécurité ligne par ligne (Row Level Security)
alter table public.profiles enable row level security;
alter table public.service_state enable row level security;
alter table public.assignments enable row level security;
alter table public.assignment_log enable row level security;

-- Aucun accès sans connexion
revoke all on public.profiles, public.service_state, public.assignments, public.assignment_log from anon;
revoke all on sequence public.assignment_log_id_seq from anon, authenticated;
revoke insert, delete on public.profiles from authenticated;
revoke insert, delete on public.service_state from authenticated;
revoke insert, update, delete on public.assignment_log from authenticated;

drop policy if exists p_profiles_select on public.profiles;
create policy p_profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_member());
drop policy if exists p_profiles_update_self on public.profiles;
create policy p_profiles_update_self on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
drop policy if exists p_profiles_update_admin on public.profiles;
create policy p_profiles_update_admin on public.profiles for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists p_state_select on public.service_state;
create policy p_state_select on public.service_state for select to authenticated using (public.is_member());
drop policy if exists p_state_update on public.service_state;
create policy p_state_update on public.service_state for update to authenticated
  using (public.is_admin()) with check (public.is_admin());

drop policy if exists p_asg_select on public.assignments;
create policy p_asg_select on public.assignments for select to authenticated using (public.is_member());
drop policy if exists p_asg_insert on public.assignments;
create policy p_asg_insert on public.assignments for insert to authenticated with check (public.is_member());
drop policy if exists p_asg_update on public.assignments;
create policy p_asg_update on public.assignments for update to authenticated
  using (public.is_member()) with check (public.is_member());
drop policy if exists p_asg_delete on public.assignments;
create policy p_asg_delete on public.assignments for delete to authenticated using (public.is_member());

drop policy if exists p_log_select on public.assignment_log;
create policy p_log_select on public.assignment_log for select to authenticated using (public.is_member());

-- 9b. Droits d'accès aux tables pour les utilisateurs connectés
--     (les nouveaux projets Supabase ne les donnent plus automatiquement ; les règles RLS ci-dessus restent appliquées)
grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select, update on public.service_state to authenticated;
grant select, insert, update, delete on public.assignments to authenticated;
grant select on public.assignment_log to authenticated;
grant execute on function public.is_admin(), public.is_member(), public.my_doc(), public.auto_parts(text) to authenticated;

-- 10. Mise à jour en direct sur tous les téléphones
do $$ begin
  alter publication supabase_realtime add table public.service_state;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.assignments;
exception when duplicate_object then null; end $$;
alter table public.assignments replica identity full;

-- 13. Rôle secrétaire : consulte tout le planning, ne modifie que les lignes d'intérimaires
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check check (role in ('admin','member','secretary'));
create or replace function public.is_secretary() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'secretary' and active);
$$;
create or replace function public.is_interim(d text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.service_state s, jsonb_array_elements(coalesce(s.data->'docs','[]'::jsonb)) x
                 where x->>'id' = d and coalesce((x->>'tmp')::boolean, false));
$$;
create or replace function public.guard_assignment() returns trigger
language plpgsql security definer set search_path = public as $$
declare prev text; mine text;
begin
  if auth.uid() is null or public.is_admin() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if public.is_secretary() then
    if (tg_op <> 'INSERT' and not public.is_interim(old.doc_id)) or (tg_op <> 'DELETE' and not public.is_interim(new.doc_id)) then
      raise exception 'Les secrétaires ne modifient que les lignes d''intérimaires';
    end if;
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  mine := public.my_doc();
  if tg_op = 'DELETE' then
    if mine is null or old.doc_id is distinct from mine then raise exception 'Vous ne pouvez modifier que votre ligne'; end if;
    if public.auto_parts(old.post_id) <> '' then raise exception 'Le bloc et la consultation sont gérés par l''administrateur'; end if;
    return old;
  end if;
  if mine is null or new.doc_id is distinct from mine then raise exception 'Vous ne pouvez modifier que votre ligne'; end if;
  if tg_op = 'UPDATE' and (new.day <> old.day or new.doc_id <> old.doc_id) then raise exception 'Modification interdite'; end if;
  select post_id into prev from public.assignments where day = new.day and doc_id = new.doc_id;
  if public.auto_parts(new.post_id) <> public.auto_parts(prev) then
    raise exception 'Le bloc et la consultation sont gérés par l''administrateur';
  end if;
  return new;
end $$;
grant execute on function public.is_secretary(), public.is_interim(text) to authenticated;

-- 11. APRÈS avoir créé votre propre compte (Authentication > Users > Add user),
--     remplacez l'adresse et le nom ci-dessous, puis exécutez ces lignes seules.
--     Ensuite, reliez chaque compte à sa ligne dans l'appli (Réglages > Comptes).
-- update public.profiles set role = 'admin', active = true, display_name = 'Votre nom'
--   where email = 'votre.adresse@exemple.fr';
