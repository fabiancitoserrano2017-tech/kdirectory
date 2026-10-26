-- =====================================================================
-- KASTOR CENTRAL · permisos por persona
-- Correr DESPUÉS de supabase-v3-actualizacion.sql. Se puede volver a correr.
--
--   Juan David  Founder · usuario maestro  → todo + ajustes + accesos
--   Fabián      Founder                    → todo + ajustes
--   Natalia     COO (accionista 20%)       → todo; Kastor Code solo lectura
--   Yohana      CMO                        → todo; Kastor Code solo lectura
--   Iris        CTO                        → todo menos BM; edita Kastor Code
--
-- Mientras NADIE tenga correo cargado en k_team, cualquier usuario con sesión
-- entra como maestro (para no dejarte afuera al instalar). Apenas cargues el
-- primer correo, solo entran las personas con correo en el equipo.
-- PON PRIMERO TU CORREO (el que usas para entrar a Central).
-- =====================================================================

alter table k_team add column if not exists access text;   -- master | founder | coo | cmo | cto
alter table k_team add column if not exists title  text;   -- cargo visible

-- Accesos del equipo (por nombre)
update k_team set access = 'master',  title = coalesce(title, 'Founder') where name ilike 'juan david%';
update k_team set access = 'founder', title = coalesce(title, 'Founder') where name ilike 'fabi%';
update k_team set access = 'coo', title = 'COO', role = 'socio', equity_pct = 20 where name ilike 'natalia%';
update k_team set access = 'cmo', title = 'CMO' where name ilike 'yohana%';
insert into k_team (name, role, access, title, pod, active, notes)
select 'Iris Arteaga', 'colaboradora', 'cto', 'CTO', 'tecnico', true, 'CTO de Kastor Code (software).'
where not exists (select 1 from k_team where name ilike 'iris%');
update k_team set access = 'cto', title = 'CTO' where name ilike 'iris%';

-- Correos de acceso (descomenta y completa; deben ser los mismos de Authentication → Users)
-- update k_team set email = 'TU-CORREO@gmail.com' where name ilike 'juan david%';
-- update k_team set email = 'correo-fabian@gmail.com' where name ilike 'fabi%';
-- update k_team set email = 'correo-natalia@gmail.com' where name ilike 'natalia%';
-- update k_team set email = 'correo-yohana@gmail.com' where name ilike 'yohana%';
-- update k_team set email = 'correo-iris@gmail.com' where name ilike 'iris%';

-- ---------------------------------------------------------------------
-- Funciones de permiso
-- ---------------------------------------------------------------------
create or replace function k_role() returns text
language sql stable security definer set search_path = public as $$
  select case
    when not exists (select 1 from k_team where coalesce(email, '') <> '') then 'master'
    else coalesce((select coalesce(access, 'coo') from k_team
                   where active and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
                   limit 1), 'none')
  end;
$$;
create or replace function k_is_member() returns boolean language sql stable security definer set search_path = public as $$ select k_role() <> 'none' $$;
create or replace function k_can_admin() returns boolean language sql stable security definer set search_path = public as $$ select k_role() in ('master','founder') $$;
create or replace function k_can_code()  returns boolean language sql stable security definer set search_path = public as $$ select k_role() in ('master','founder','cto') $$;
create or replace function k_can_bm()    returns boolean language sql stable security definer set search_path = public as $$ select k_role() in ('master','founder','coo','cmo') $$;
create or replace function k_deal_div(d uuid) returns text language sql stable security definer set search_path = public as $$ select division from k_deals where id = d $$;
create or replace function k_div_ok(div text) returns boolean language sql stable security definer set search_path = public as $$ select coalesce(div, '') <> 'code' or k_can_code() $$;
grant execute on function k_role() to authenticated;

-- ---------------------------------------------------------------------
-- Políticas: lectura y escritura por tabla
-- ---------------------------------------------------------------------
do $$
declare
  t text; r text; w text;
  rules jsonb := jsonb_build_object(
    -- tabla            lectura                                                           escritura
    'k_settings',     jsonb_build_array('true',                                           'k_can_admin()'),
    'k_team',         jsonb_build_array('true',                                           'k_can_admin()'),
    'k_products',     jsonb_build_array('true',                                           'k_div_ok(division)'),
    'k_deals',        jsonb_build_array('true',                                           'k_div_ok(division)'),
    'k_deal_items',   jsonb_build_array('true',                                           'k_div_ok(k_deal_div(deal_id))'),
    'k_print_jobs',   jsonb_build_array('true',                                           'k_div_ok(k_deal_div(deal_id))'),
    'k_activities',   jsonb_build_array('true',                                           'k_div_ok(k_deal_div(deal_id))'),
    'k_tasks',        jsonb_build_array('true',                                           'k_div_ok(k_deal_div(deal_id))'),
    'k_payments',     jsonb_build_array('k_can_bm() or k_deal_div(deal_id) = ''code''',  '(k_can_bm() and k_div_ok(k_deal_div(deal_id))) or (k_can_code() and k_deal_div(deal_id) = ''code'')'),
    'k_expenses',     jsonb_build_array('k_can_bm() or division = ''code'' or k_deal_div(deal_id) = ''code''',
                                        '(k_can_bm() and k_div_ok(coalesce(division, k_deal_div(deal_id)))) or (k_can_code() and (division = ''code'' or k_deal_div(deal_id) = ''code''))'),
    'k_recurring',    jsonb_build_array('k_can_bm()',                                     'k_can_bm()'),
    'k_dividends',    jsonb_build_array('k_can_bm()',                                     'k_can_admin()'),
    'k_companies',    jsonb_build_array('true','true'),
    'k_contacts',     jsonb_build_array('true','true'),
    'k_filaments',    jsonb_build_array('true','true'),
    'k_filament_moves', jsonb_build_array('true','true'),
    'k_events',       jsonb_build_array('true','true'),
    'k_content',      jsonb_build_array('true','true'),
    'k_goals',        jsonb_build_array('true','true')
  );
begin
  for t in select jsonb_object_keys(rules) loop
    r := rules -> t ->> 0; w := rules -> t ->> 1;
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I on %I', t || '_team', t);
    execute format('drop policy if exists %I on %I', t || '_read', t);
    execute format('drop policy if exists %I on %I', t || '_ins', t);
    execute format('drop policy if exists %I on %I', t || '_upd', t);
    execute format('drop policy if exists %I on %I', t || '_del', t);
    execute format('create policy %I on %I for select to authenticated using (k_is_member() and (%s))', t || '_read', t, r);
    execute format('create policy %I on %I for insert to authenticated with check (k_is_member() and (%s))', t || '_ins', t, w);
    execute format('create policy %I on %I for update to authenticated using (k_is_member() and (%s)) with check (k_is_member() and (%s))', t || '_upd', t, w, w);
    execute format('create policy %I on %I for delete to authenticated using (k_is_member() and (%s))', t || '_del', t, w);
  end loop;
end $$;
