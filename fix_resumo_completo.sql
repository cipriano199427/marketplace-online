-- Correcao definitiva do resumo por SKU para periodos maiores.
-- Evita o limite de linhas do PostgREST/Supabase retornando o resumo inteiro
-- como um unico JSONB. Nao apaga nem altera vendas/importacoes existentes.

create or replace function public.get_sales_summary_json(p_start date, p_end date)
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with eligible as (
    select s.*
    from public.sales_items s
    join public.imports i on i.id = s.import_id
    where
      (not s.aggregate_period and s.sale_date between p_start and p_end)
      or
      (s.aggregate_period and i.period_start = p_start and i.period_end = p_end)
  ),
  sku_identity as (
    select distinct on (s.sku)
      s.sku,
      nullif(trim(s.product), '') as produto,
      nullif(trim(s.variation), '') as variacao
    from public.sales_items s
    where nullif(trim(s.product), '') is not null
       or nullif(trim(s.variation), '') is not null
    order by
      s.sku,
      case when nullif(trim(s.product), '') is null then 1 else 0 end,
      s.created_at desc,
      s.id desc
  ),
  agg as (
    select
      e.sku,
      coalesce(sum(case when e.marketplace = 'TikTok' then e.units_net else 0 end),0) as tiktok_liquido,
      coalesce(sum(case when e.marketplace = 'Mercado Livre' then e.units_net else 0 end),0) as mercado_livre_liquido,
      coalesce(sum(case when e.marketplace = 'Shopee' then e.units_net else 0 end),0) as shopee_liquido,
      coalesce(sum(case when e.marketplace = 'SHEIN' then e.units_net else 0 end),0) as shein_liquido,
      coalesce(sum(case when e.marketplace = 'Amazon' then e.units_net else 0 end),0) as amazon_pedidas,
      coalesce(sum(case when e.marketplace = 'Droga Raia' then e.units_net else 0 end),0) as droga_raia_liquido,
      coalesce(sum(case when e.marketplace = 'Magazine Luiza' then e.units_net else 0 end),0) as magazine_luiza_liquido,
      coalesce(sum(case when e.marketplace = 'Beleza na Web' then e.units_net else 0 end),0) as beleza_na_web_liquido,
      bool_or(e.sku_pending) as sku_pendente
    from eligible e
    group by e.sku
  ),
  totals as (
    select
      a.*,
      (a.tiktok_liquido + a.mercado_livre_liquido + a.shopee_liquido + a.shein_liquido +
       a.amazon_pedidas + a.droga_raia_liquido + a.magazine_luiza_liquido + a.beleza_na_web_liquido) as total_considerado
    from agg a
  ),
  final_rows as (
    select
      t.sku,
      i.produto,
      i.variacao,
      t.tiktok_liquido,
      t.mercado_livre_liquido,
      t.shopee_liquido,
      t.shein_liquido,
      t.amazon_pedidas,
      t.droga_raia_liquido,
      t.magazine_luiza_liquido,
      t.beleza_na_web_liquido,
      t.total_considerado,
      round(t.total_considerado / greatest(1, (p_end - p_start + 1)), 0) as media_dia,
      ceil(t.total_considerado * 1.15)::bigint as pedido_sugerido,
      t.sku_pendente
    from totals t
    left join sku_identity i on i.sku = t.sku
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'sku', f.sku,
        'produto', f.produto,
        'variacao', f.variacao,
        'tiktok_liquido', f.tiktok_liquido,
        'mercado_livre_liquido', f.mercado_livre_liquido,
        'shopee_liquido', f.shopee_liquido,
        'shein_liquido', f.shein_liquido,
        'amazon_pedidas', f.amazon_pedidas,
        'droga_raia_liquido', f.droga_raia_liquido,
        'magazine_luiza_liquido', f.magazine_luiza_liquido,
        'beleza_na_web_liquido', f.beleza_na_web_liquido,
        'total_considerado', f.total_considerado,
        'media_dia', f.media_dia,
        'pedido_sugerido', f.pedido_sugerido,
        'sku_pendente', f.sku_pendente
      )
      order by f.total_considerado desc, f.sku
    ),
    '[]'::jsonb
  )
  from final_rows f;
$$;

grant execute on function public.get_sales_summary_json(date, date) to authenticated;

-- Indices uteis para os filtros por periodo e agrupamento por SKU.
create index if not exists sales_items_sale_date_idx on public.sales_items (sale_date);
create index if not exists sales_items_sku_created_at_idx on public.sales_items (sku, created_at desc, id desc);
