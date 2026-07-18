-- =========================================================
-- Esquema: Bóveda de claves
-- Pegar este archivo completo en Supabase → SQL Editor → Run
-- =========================================================

-- 1. Tabla de claves
create table if not exists public.keys (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  product text not null check (product in ('bypass', 'complex')),
  duration text not null check (duration in ('daily', 'weekly', 'monthly', 'quarterly', 'permanent')),
  status text not null default 'available' check (status in ('available', 'claimed')),
  expires_at timestamptz not null,
  claimed_by uuid references auth.users(id),
  claimed_at timestamptz,
  created_at timestamptz not null default now()
);

-- Índice para buscar rápido claves disponibles y no vencidas,
-- filtrando por producto y duración (que es como las busca el frontend)
create index if not exists idx_keys_available
  on public.keys (product, duration, status, expires_at)
  where status = 'available';

-- 2. Seguridad a nivel de fila (RLS)
alter table public.keys enable row level security;

-- Cualquier usuario autenticado puede VER el conteo/estado de claves
-- (usado por el dashboard para mostrar cuántas quedan disponibles)
create policy "usuarios autenticados pueden leer claves disponibles"
  on public.keys for select
  to authenticated
  using (status = 'available');

-- Un usuario puede ver la clave que él mismo reclamó
create policy "usuarios ven sus propias claves reclamadas"
  on public.keys for select
  to authenticated
  using (claimed_by = auth.uid());

-- Nadie puede insertar/actualizar/borrar directamente desde el cliente;
-- eso solo ocurre a través de la función claim_key() de abajo
-- (que corre con permisos elevados) o desde el panel de Supabase.

-- 3. Función atómica para "sacar" una clave del pool,
-- filtrando por producto y duración
-- SECURITY DEFINER + row locking evita que dos usuarios que
-- aprietan el botón al mismo tiempo se lleven la misma clave.
create or replace function public.claim_key(p_product text, p_duration text)
returns table (code text, expires_at timestamptz)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'No autenticado';
  end if;

  select k.id into v_id
  from public.keys k
  where k.status = 'available'
    and k.product = p_product
    and k.duration = p_duration
    and k.expires_at > now()
  order by k.created_at asc
  limit 1
  for update skip locked;

  if v_id is null then
    return; -- no hay claves disponibles: devuelve set vacío
  end if;

  return query
  update public.keys k
  set status = 'claimed',
      claimed_by = auth.uid(),
      claimed_at = now()
  where k.id = v_id
  returning k.code, k.expires_at;
end;
$$;

-- Solo usuarios logueados pueden ejecutar la función
revoke all on function public.claim_key(text, text) from public;
grant execute on function public.claim_key(text, text) to authenticated;

-- =========================================================
-- 4. Cargar claves de ejemplo (opcional, borrar en producción)
-- =========================================================
insert into public.keys (code, product, duration, expires_at) values
  ('AB12-CD34-EF56', 'bypass',  'daily',    now() + interval '1 day'),
  ('GH78-IJ90-KL12', 'bypass',  'weekly',   now() + interval '7 days'),
  ('MN34-OP56-QR78', 'bypass',  'monthly',  now() + interval '30 days'),
  ('ST90-UV12-WX34', 'complex', 'monthly',  now() + interval '30 days'),
  ('YZ56-AB78-CD90', 'complex', 'permanent', now() + interval '3650 days');
