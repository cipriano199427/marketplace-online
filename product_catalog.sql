-- Execute este arquivo UMA VEZ no SQL Editor do Supabase.
-- Ele cria o cadastro mestre de nomes por SKU.
-- Os nomes originais das vendas continuam preservados em sales_items.

create or replace function public.is_marketplace_admin()
returns boolean
language sql
stable
security invoker
set search_path = public
as $$
  select lower(coalesce(auth.jwt() ->> 'email', '')) = 'luzmakeupadm@gmail.com';
$$;

grant execute on function public.is_marketplace_admin() to authenticated;

create table if not exists public.product_catalog (
  sku text primary key,
  product_name text not null,
  variation_name text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  constraint product_catalog_sku_not_blank check (length(trim(sku)) > 0),
  constraint product_catalog_name_not_blank check (length(trim(product_name)) > 0)
);

alter table public.product_catalog enable row level security;

drop policy if exists "authenticated users can read product catalog" on public.product_catalog;
drop policy if exists "admin can insert product catalog" on public.product_catalog;
drop policy if exists "admin can update product catalog" on public.product_catalog;
drop policy if exists "admin can delete product catalog" on public.product_catalog;

create policy "authenticated users can read product catalog"
on public.product_catalog for select to authenticated
using (true);

create policy "admin can insert product catalog"
on public.product_catalog for insert to authenticated
with check (public.is_marketplace_admin());

create policy "admin can update product catalog"
on public.product_catalog for update to authenticated
using (public.is_marketplace_admin())
with check (public.is_marketplace_admin());

create policy "admin can delete product catalog"
on public.product_catalog for delete to authenticated
using (public.is_marketplace_admin());

grant select, insert, update, delete on public.product_catalog to authenticated;

create index if not exists product_catalog_product_name_idx
on public.product_catalog (lower(product_name));
