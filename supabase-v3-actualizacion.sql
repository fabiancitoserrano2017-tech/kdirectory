-- =====================================================================
-- KASTOR CENTRAL · actualización a v3
-- Pegar en Supabase → SQL Editor → Run. Se puede correr más de una vez.
-- 1) Divisiones: Lab y Works pasan a Tech (las nuevas son Design / Code / Tech)
-- 2) Seguridad: solo las personas cargadas en Ajustes → Equipo ven los datos
-- =====================================================================

-- 1) DIVISIONES ---------------------------------------------------------
update k_products  set division = 'tech' where division in ('lab','works');
update k_deals     set division = 'tech' where division in ('lab','works');
update k_expenses  set division = 'tech' where division in ('lab','works');
update k_recurring set division = 'tech' where division in ('lab','works');
update k_events    set division = 'tech' where division in ('lab','works');
update k_content   set division = 'tech' where division in ('lab','works');

-- Metas: si había meta de Lab y de Works en el mismo mes, se suman en Tech
insert into k_goals (period, division, metric, target)
select period, 'tech', metric, sum(target)
from k_goals where division in ('lab','works')
group by period, metric
on conflict (period, division, metric) do update set target = k_goals.target + excluded.target;
delete from k_goals where division in ('lab','works');

-- 1b) CATÁLOGO MAESTRO: columnas nuevas (post-procesado, escalable, link del modelo, otras opciones)
alter table k_products add column if not exists post_h numeric default 0;
alter table k_products add column if not exists escalable boolean default false;
alter table k_products add column if not exists model_url text;
alter table k_products add column if not exists colors_other text;

-- 2) SEGURIDAD ----------------------------------------------------------
-- Antes: cualquier usuario con sesión veía todo. Ahora la app está en internet,
-- así que solo entra quien tenga su correo en k_team (activo).
-- IMPORTANTE: antes de correr esta parte, pon tu correo en Ajustes → Equipo.
-- Mientras NINGÚN integrante tenga correo cargado, sigue abierto a usuarios
-- con sesión (para no dejar a nadie afuera al instalar).

create or replace function k_is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
      select 1 from k_team
      where active and lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
    )
    or not exists (select 1 from k_team where email is not null and email <> '');
$$;

do $$
declare t text;
begin
  foreach t in array array['k_settings','k_team','k_products','k_companies','k_contacts','k_deals','k_deal_items',
    'k_payments','k_recurring','k_expenses','k_dividends','k_filaments','k_filament_moves','k_print_jobs',
    'k_activities','k_tasks','k_events','k_content','k_goals']
  loop
    execute format('drop policy if exists %I_team on %I', t, t);
    execute format('create policy %I_team on %I for all to authenticated using (k_is_member()) with check (k_is_member())', t, t);
  end loop;
end $$;

drop policy if exists "kastor fotos escritura" on storage.objects;
create policy "kastor fotos escritura" on storage.objects for insert to authenticated
  with check (bucket_id = 'kastor-fotos' and k_is_member());
drop policy if exists "kastor fotos cambio" on storage.objects;
create policy "kastor fotos cambio" on storage.objects for update to authenticated
  using (bucket_id = 'kastor-fotos' and k_is_member());
drop policy if exists "kastor fotos borrado" on storage.objects;
create policy "kastor fotos borrado" on storage.objects for delete to authenticated
  using (bucket_id = 'kastor-fotos' and k_is_member());
