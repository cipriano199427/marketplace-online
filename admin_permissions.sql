-- Execute este arquivo no SQL Editor se o banco ja foi criado.

-- ============================================================
-- ADMINISTRADOR: somente luzmakeupadm@gmail.com pode alterar dados
-- Usuários autenticados comuns ficam somente com leitura.
-- ============================================================

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

-- Substitui as políticas permissivas antigas de imports.
drop policy if exists "authenticated users can read imports" on public.imports;
drop policy if exists "authenticated users can insert imports" on public.imports;
drop policy if exists "authenticated users can update imports" on public.imports;
drop policy if exists "authenticated users can delete imports" on public.imports;
drop policy if exists "admin can insert imports" on public.imports;
drop policy if exists "admin can update imports" on public.imports;
drop policy if exists "admin can delete imports" on public.imports;

create policy "authenticated users can read imports"
on public.imports for select to authenticated
using (true);

create policy "admin can insert imports"
on public.imports for insert to authenticated
with check (public.is_marketplace_admin() and (select auth.uid()) = created_by);

create policy "admin can update imports"
on public.imports for update to authenticated
using (public.is_marketplace_admin())
with check (public.is_marketplace_admin());

create policy "admin can delete imports"
on public.imports for delete to authenticated
using (public.is_marketplace_admin());

-- Substitui as políticas permissivas antigas de sales_items.
drop policy if exists "authenticated users can read sales" on public.sales_items;
drop policy if exists "authenticated users can insert sales" on public.sales_items;
drop policy if exists "authenticated users can update sales" on public.sales_items;
drop policy if exists "authenticated users can delete sales" on public.sales_items;
drop policy if exists "admin can insert sales" on public.sales_items;
drop policy if exists "admin can update sales" on public.sales_items;
drop policy if exists "admin can delete sales" on public.sales_items;

create policy "authenticated users can read sales"
on public.sales_items for select to authenticated
using (true);

create policy "admin can insert sales"
on public.sales_items for insert to authenticated
with check (public.is_marketplace_admin());

create policy "admin can update sales"
on public.sales_items for update to authenticated
using (public.is_marketplace_admin())
with check (public.is_marketplace_admin());

create policy "admin can delete sales"
on public.sales_items for delete to authenticated
using (public.is_marketplace_admin());

-- Arquivos originais: todos autenticados podem ler; somente admin pode alterar.
drop policy if exists "authenticated can read marketplace files" on storage.objects;
drop policy if exists "authenticated can upload marketplace files" on storage.objects;
drop policy if exists "authenticated can update marketplace files" on storage.objects;
drop policy if exists "authenticated can delete marketplace files" on storage.objects;
drop policy if exists "admin can upload marketplace files" on storage.objects;
drop policy if exists "admin can update marketplace files" on storage.objects;
drop policy if exists "admin can delete marketplace files" on storage.objects;

create policy "authenticated can read marketplace files"
on storage.objects for select to authenticated
using (bucket_id = 'marketplace-files');

create policy "admin can upload marketplace files"
on storage.objects for insert to authenticated
with check (bucket_id = 'marketplace-files' and public.is_marketplace_admin());

create policy "admin can update marketplace files"
on storage.objects for update to authenticated
using (bucket_id = 'marketplace-files' and public.is_marketplace_admin())
with check (bucket_id = 'marketplace-files' and public.is_marketplace_admin());

create policy "admin can delete marketplace files"
on storage.objects for delete to authenticated
using (bucket_id = 'marketplace-files' and public.is_marketplace_admin());
