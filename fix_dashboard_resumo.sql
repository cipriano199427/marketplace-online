-- Correcao do dashboard por SKU.
-- Execute uma vez no Supabase SQL Editor.
-- Nao apaga importacoes nem vendas existentes.
--
-- Corrige dois pontos:
-- 1) Produto/variacao permanecem estaveis ao trocar 7/15/30 dias.
-- 2) O resumo completo e empacotado em uma unica linha JSONB, evitando que
--    o limite de linhas do PostgREST corte SKUs em periodos maiores.

create or replace function public.get_sales_summary(p_start date, p_end date)
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
  )
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
  order by t.total_considerado desc, t.sku;
$$;

grant execute on function public.get_sales_summary(date, date) to authenticated;

create or replace function public.get_sales_summary_payload(p_start date, p_end date)
returns table (payload jsonb)
language sql
stable
security invoker
set search_path = public
as $$
  select coalesce(
    jsonb_agg(to_jsonb(s) order by s.total_considerado desc, s.sku),
    '[]'::jsonb
  ) as payload
  from public.get_sales_summary(p_start, p_end) s;
$$;

grant execute on function public.get_sales_summary_payload(date, date) to authenticated;

create index if not exists sales_items_sale_date_idx on public.sales_items (sale_date);
create index if not exists sales_items_sku_created_at_idx on public.sales_items (sku, created_at desc, id desc);
