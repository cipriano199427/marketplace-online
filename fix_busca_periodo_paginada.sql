-- Correcao definitiva da busca/resumo por periodo.
-- Execute uma vez no Supabase SQL Editor.
-- Nao apaga nem altera vendas/importacoes existentes.
--
-- O problema corrigido:
-- periodos maiores podem ter mais de 1.000 SKUs. Em vez de depender do
-- limite/Range do PostgREST, esta funcao pagina DENTRO do PostgreSQL.
-- A busca tambem e aplicada antes da paginacao, entao um SKU que aparece
-- em 15 dias nao some ao selecionar 30 dias por causa de corte de resultados.

create or replace function public.get_sales_summary_page(
  p_start date,
  p_end date,
  p_search text default null,
  p_offset integer default 0,
  p_limit integer default 500
)
returns table (
  sku text,
  produto text,
  variacao text,
  tiktok_liquido numeric,
  mercado_livre_liquido numeric,
  shopee_liquido numeric,
  shein_liquido numeric,
  amazon_pedidas numeric,
  droga_raia_liquido numeric,
  magazine_luiza_liquido numeric,
  beleza_na_web_liquido numeric,
  total_considerado numeric,
  media_dia numeric,
  pedido_sugerido bigint,
  sku_pendente boolean
)
language sql
stable
security invoker
set search_path = public
as $$
  with base as (
    select
      s.sku,
      coalesce(nullif(trim(c.product_name), ''), s.produto) as produto,
      coalesce(nullif(trim(c.variation_name), ''), s.variacao) as variacao,
      s.tiktok_liquido,
      s.mercado_livre_liquido,
      s.shopee_liquido,
      s.shein_liquido,
      s.amazon_pedidas,
      s.droga_raia_liquido,
      s.magazine_luiza_liquido,
      s.beleza_na_web_liquido,
      s.total_considerado,
      s.media_dia,
      s.pedido_sugerido,
      s.sku_pendente
    from public.get_sales_summary(p_start, p_end) s
    left join public.product_catalog c on c.sku = s.sku
  ),
  filtered as (
    select b.*
    from base b
    where
      nullif(trim(coalesce(p_search, '')), '') is null
      or concat_ws(' ', b.sku, b.produto, b.variacao) ilike '%' || trim(p_search) || '%'
      or exists (
        select 1
        from public.sales_items raw
        where raw.sku = b.sku
          and concat_ws(' ', raw.sku, raw.product, raw.variation) ilike '%' || trim(p_search) || '%'
      )
  )
  select
    f.sku,
    f.produto,
    f.variacao,
    f.tiktok_liquido,
    f.mercado_livre_liquido,
    f.shopee_liquido,
    f.shein_liquido,
    f.amazon_pedidas,
    f.droga_raia_liquido,
    f.magazine_luiza_liquido,
    f.beleza_na_web_liquido,
    f.total_considerado,
    f.media_dia,
    f.pedido_sugerido,
    f.sku_pendente
  from filtered f
  order by f.total_considerado desc, f.sku
  offset greatest(coalesce(p_offset, 0), 0)
  limit least(greatest(coalesce(p_limit, 500), 1), 500);
$$;

grant execute on function public.get_sales_summary_page(date, date, text, integer, integer) to authenticated;

-- Ajuda a busca das variacoes de nome por SKU sem varrer a tabela inteira para cada SKU.
create index if not exists sales_items_sku_idx on public.sales_items (sku);
