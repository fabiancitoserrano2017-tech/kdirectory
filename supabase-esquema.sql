-- =====================================================================
-- KASTOR CENTRAL · esquema Supabase (v2)
-- Pegar completo en Supabase → SQL Editor → Run. Es idempotente:
-- se puede volver a correr sin romper nada.
-- La tabla vieja `kastor_workspace` NO se toca: la app la lee una vez
-- para migrar (Configuración → Importar versión anterior).
-- =====================================================================

create extension if not exists pgcrypto;

-- Ajustes generales (una sola fila, id = 'main')
create table if not exists k_settings (
  id text primary key default 'main',
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Equipo: socios, colaboradoras e inversionista
create table if not exists k_team (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  role text not null default 'colaboradora',      -- socio | colaboradora | inversionista
  pod text,                                       -- tecnico | negocio
  equity_pct numeric,                             -- null = por definir
  margin_pct numeric,                             -- % del margen neto por pedido (colaboradoras)
  hourly_bs numeric,
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Catálogo Maestro (DS-XXXX / TCH-XXXX). Variantes de tamaño = filas propias.
create table if not exists k_products (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  division text not null default 'design',        -- design | tech | code
  category text,
  name text not null,
  variant text,                                   -- ej. "10 cm", "1:100"
  description text,
  tags text[] default '{}',
  size_mm text,
  pieces int,
  fase text,
  score int,
  weight_g numeric default 0,
  print_time_h numeric default 0,
  filament_rate numeric,                          -- Bs/g; null = usa el global
  purge_pct numeric default 0,                    -- sobrecosto por purga multicolor
  insumos_bs numeric default 0,
  empaque_bs numeric default 0,
  diseno_h numeric default 0,
  mano_obra_bs numeric default 0,
  merma_pct numeric default 0,
  price_bs numeric default 0,
  price_wholesale_bs numeric,
  model_source text,                              -- propio | MakerWorld | ...
  drive_url text,
  colors text[] default '{}',
  photo_url text,
  active boolean not null default true,
  notes text,
  post_h numeric default 0,
  escalable boolean default false,
  model_url text,
  colors_other text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- CRM
create table if not exists k_companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text,                                      -- colegio | universidad | empresa | tienda | evento | otro
  nit text,
  city text default 'Santa Cruz',
  phone text,
  email text,
  owner_id uuid references k_team(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists k_contacts (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  email text,
  company_id uuid references k_companies(id) on delete set null,
  segment int,                                    -- 1..6 (análisis de mercado)
  lifecycle text not null default 'lead',         -- lead | prospecto | cliente | recurrente | perdido
  source text,                                    -- TikTok | Instagram | WhatsApp | Facebook | Referido | Feria | Web | SBA
  owner_id uuid references k_team(id) on delete set null,
  tags text[] default '{}',
  birthday date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Negocios (embudo) = cotización + pedido
create table if not exists k_deals (
  id uuid primary key default gen_random_uuid(),
  number serial,
  title text not null,
  contact_id uuid references k_contacts(id) on delete set null,
  company_id uuid references k_companies(id) on delete set null,
  division text default 'design',
  stage text not null default 'nuevo',            -- nuevo | cotizado | pagado | produccion | entregado | perdido
  source text,
  owner_id uuid references k_team(id) on delete set null,
  expected_date date,
  delivery_date date,
  discount_bs numeric default 0,
  shipping_bs numeric default 0,
  amount_manual_bs numeric,                       -- si no hay líneas
  lost_reason text,
  collaborators jsonb default '[]'::jsonb,        -- [{member_id, pct}]
  personalization text,
  notes text,
  stage_changed_at timestamptz default now(),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists k_deal_items (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid not null references k_deals(id) on delete cascade,
  product_id uuid references k_products(id) on delete set null,
  description text,
  qty numeric not null default 1,
  unit_price_bs numeric not null default 0,
  unit_cost_bs numeric default 0,                 -- foto del costo al cotizar
  unit_hours numeric default 0,
  unit_grams numeric default 0,
  personalization text,
  sort int default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Cobros (el ingreso real es lo cobrado, no lo cotizado)
create table if not exists k_payments (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid references k_deals(id) on delete set null,
  date date not null default current_date,
  amount_bs numeric not null,
  method text,                                    -- QR | Efectivo | Transferencia | Tarjeta
  kind text default 'pago',                       -- anticipo | saldo | pago
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Gastos y recurrentes
create table if not exists k_recurring (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  description text not null,
  payee text,
  amount_bs numeric not null default 0,
  day int default 1,
  division text,
  start_month text,                               -- YYYY-MM
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists k_expenses (
  id uuid primary key default gen_random_uuid(),
  date date not null default current_date,
  category text not null,
  description text,
  payee text,
  amount_bs numeric not null default 0,
  division text,                                  -- null = general
  recurring_id uuid references k_recurring(id) on delete set null,
  period text,                                    -- YYYY-MM (para recurrentes)
  team_member_id uuid references k_team(id) on delete set null,
  deal_id uuid references k_deals(id) on delete set null,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists k_expenses_recurring_period on k_expenses(recurring_id, period) where recurring_id is not null;

create table if not exists k_dividends (
  id uuid primary key default gen_random_uuid(),
  date date not null default current_date,
  amount_bs numeric not null,
  split jsonb not null default '[]'::jsonb,       -- [{member_id, name, pct, amount}]
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Producción e inventario
create table if not exists k_filaments (
  id uuid primary key default gen_random_uuid(),
  material text not null default 'PLA',
  color text not null,
  hex text,
  brand text,
  stock_g numeric not null default 0,
  min_g numeric not null default 250,
  cost_per_kg_bs numeric default 160,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists k_filament_moves (
  id uuid primary key default gen_random_uuid(),
  filament_id uuid not null references k_filaments(id) on delete cascade,
  date date not null default current_date,
  delta_g numeric not null,
  reason text,                                    -- compra | consumo | ajuste | purga
  job_id uuid,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists k_print_jobs (
  id uuid primary key default gen_random_uuid(),
  deal_id uuid references k_deals(id) on delete set null,
  product_id uuid references k_products(id) on delete set null,
  title text not null,
  qty numeric default 1,
  hours numeric not null default 0,
  grams numeric default 0,
  filament_id uuid references k_filaments(id) on delete set null,
  slot text default 'dia',                        -- noche | dia | finde
  date date,
  status text not null default 'cola',            -- cola | imprimiendo | hecho | fallido
  sort int default 0,
  notes text,
  done_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Equipo, marketing y metas
create table if not exists k_activities (
  id uuid primary key default gen_random_uuid(),
  type text not null default 'nota',              -- nota | whatsapp | llamada | reunion | email | etapa
  body text,
  contact_id uuid references k_contacts(id) on delete cascade,
  deal_id uuid references k_deals(id) on delete cascade,
  company_id uuid references k_companies(id) on delete cascade,
  author text,
  at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists k_tasks (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  due date,
  assignee_id uuid references k_team(id) on delete set null,
  pod text,
  status text not null default 'pendiente',       -- pendiente | en_curso | hecha
  priority text default 'media',                  -- alta | media | baja
  deal_id uuid references k_deals(id) on delete cascade,
  contact_id uuid references k_contacts(id) on delete cascade,
  notes text,
  done_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists k_events (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  date date not null,
  end_date date,
  type text default 'comercial',                  -- comercial | feria | campaña | interno
  division text,
  goal_bs numeric,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists k_content (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  date date,
  channel text,                                   -- TikTok | Instagram | Facebook | WhatsApp | Web
  division text,
  status text not null default 'idea',            -- idea | produccion | programado | publicado
  owner_id uuid references k_team(id) on delete set null,
  event_id uuid references k_events(id) on delete set null,
  url text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists k_goals (
  id uuid primary key default gen_random_uuid(),
  period text not null,                           -- YYYY-MM
  division text not null default 'total',         -- total | design | tech | code
  metric text not null default 'ingresos',        -- ingresos | pedidos | leads | horas
  target numeric not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (period, division, metric)
);

-- ---------------------------------------------------------------------
-- updated_at automático
-- ---------------------------------------------------------------------
create or replace function k_touch() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

do $$
declare t text;
begin
  foreach t in array array['k_settings','k_team','k_products','k_companies','k_contacts','k_deals','k_deal_items',
    'k_payments','k_recurring','k_expenses','k_dividends','k_filaments','k_filament_moves','k_print_jobs',
    'k_activities','k_tasks','k_events','k_content','k_goals']
  loop
    execute format('drop trigger if exists %I_touch on %I', t, t);
    execute format('create trigger %I_touch before update on %I for each row execute function k_touch()', t, t);
    -- Seguridad: solo usuarios con sesión (el equipo) leen y escriben
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists %I_team on %I', t, t);
    execute format('create policy %I_team on %I for all to authenticated using (true) with check (true)', t, t);
    -- Tiempo real: los cambios de uno aparecen en la pantalla de los demás
    begin
      execute format('alter publication supabase_realtime add table %I', t);
    exception when duplicate_object then null; when undefined_object then null;
    end;
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- Fotos de productos: bucket público de solo lectura, escritura del equipo
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('kastor-fotos', 'kastor-fotos', true)
on conflict (id) do nothing;

drop policy if exists "kastor fotos lectura" on storage.objects;
create policy "kastor fotos lectura" on storage.objects for select
  using (bucket_id = 'kastor-fotos');
drop policy if exists "kastor fotos escritura" on storage.objects;
create policy "kastor fotos escritura" on storage.objects for insert to authenticated
  with check (bucket_id = 'kastor-fotos');
drop policy if exists "kastor fotos cambio" on storage.objects;
create policy "kastor fotos cambio" on storage.objects for update to authenticated
  using (bucket_id = 'kastor-fotos');
drop policy if exists "kastor fotos borrado" on storage.objects;
create policy "kastor fotos borrado" on storage.objects for delete to authenticated
  using (bucket_id = 'kastor-fotos');
