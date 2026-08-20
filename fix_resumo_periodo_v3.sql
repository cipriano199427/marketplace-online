-- Resumo por SKU v3: consulta completa e sem fallback truncado.
-- Execute no Supabase SQL Editor.
-- Nao apaga nem altera vendas, importacoes ou o cadastro mestre.
--
-- Esta funcao agrega DIRETAMENTE public.sales_items e devolve o resultado inteiro
-- em uma unica linha JSONB. Assim o limite de linhas do PostgREST nao pode remover
-- SKUs quando o periodo aumenta de 15 para 30 dias.

create or replace function public.get_sales_summary_payload_v3(
  p_start date,
  p_end date
)
returns table (
  payload jsonb,
  sku_count bigint
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
  agg as (
    select
      e.sku,
      coalesce(sum(e.units_net) filter (where e.marketplace = 'TikTok'), 0) as tiktok_liquido,
      coalesce(sum(e.units_net) filter (where e.marketplace = 'Mercado Livre'), 0) as mercado_livre_liquido,
      coalesce(sum(e.units_net) filter (where e.marketplace = 'Shopee'), 0) as shopee_liquido,
      coalesce(sum(e.units_net) filter (where e.marketplace = 'SHEIN'), 0) as shein_liquido,
      coalesce(sum(e.units_net) filter (where e.marketplace = 'Amazon'), 0) as amazon_pedidas,
      coalesce(sum(e.units_net) filter (where e.marketplace = 'Droga Raia'), 0) as droga_raia_liquido,
      coalesce(sum(e.units_net) filter (where e.marketplace = 'Magazine Luiza'), 0) as magazine_luiza_liquido,
      coalesce(sum(e.units_net) filter (where e.marketplace = 'Beleza na Web'), 0) as beleza_na_web_liquido,
      bool_or(e.sku_pending) as sku_pendente
    from eligible e
    group by e.sku
  ),
  identity_rows as (
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
  final_rows as (
    select
      a.sku,
      coalesce(nullif(trim(c.product_name), ''), i.produto, '') as produto,
      coalesce(nullif(trim(c.variation_name), ''), i.variacao, '') as variacao,
      a.tiktok_liquido,
      a.mercado_livre_liquido,
      a.shopee_liquido,
      a.shein_liquido,
      a.amazon_pedidas,
      a.droga_raia_liquido,
      a.magazine_luiza_liquido,
      a.beleza_na_web_liquido,
      (a.tiktok_liquido + a.mercado_livre_liquido + a.shopee_liquido + a.shein_liquido +
       a.amazon_pedidas + a.droga_raia_liquido + a.magazine_luiza_liquido + a.beleza_na_web_liquido) as total_considerado,
      a.sku_pendente
    from agg a
    left join identity_rows i on i.sku = a.sku
    left join public.product_catalog c on c.sku = a.sku
  ),
  prepared as (
    select
      f.*,
      round(f.total_considerado / greatest(1, (p_end - p_start + 1)), 0) as media_dia,
      ceil(f.total_considerado * 1.15)::bigint as pedido_sugerido
    from final_rows f
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'sku', p.sku,
          'produto', p.produto,
          'variacao', p.variacao,
          'tiktok_liquido', p.tiktok_liquido,
          'mercado_livre_liquido', p.mercado_livre_liquido,
          'shopee_liquido', p.shopee_liquido,
          'shein_liquido', p.shein_liquido,
          'amazon_pedidas', p.amazon_pedidas,
          'droga_raia_liquido', p.droga_raia_liquido,
          'magazine_luiza_liquido', p.magazine_luiza_liquido,
          'beleza_na_web_liquido', p.beleza_na_web_liquido,
          'total_considerado', p.total_considerado,
          'media_dia', p.media_dia,
          'pedido_sugerido', p.pedido_sugerido,
          'sku_pendente', p.sku_pendente
        )
        order by p.total_considerado desc, p.sku
      ),
      '[]'::jsonb
    ) as payload,
    count(*)::bigint as sku_count
  from prepared p;
$$;

grant execute on function public.get_sales_summary_payload_v3(date, date) to authenticated;

create index if not exists sales_items_sale_date_idx on public.sales_items (sale_date);
create index if not exists sales_items_sku_created_at_idx on public.sales_items (sku, created_at desc, id desc);
