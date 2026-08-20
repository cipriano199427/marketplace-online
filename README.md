# Painel de vendas por SKU - Vercel + Supabase

Este projeto transforma o painel local em um sistema compartilhado.

## Antes de publicar: segurança

A chave `sb_secret_...` que foi exposta deve ser rotacionada no Supabase. O aplicativo **não usa chave secreta**; o `index.html` contém somente a Project URL e a Publishable Key.

No Supabase, vá em **Settings > API Keys**, crie uma nova Secret Key e apague a antiga que foi exposta. Não coloque a nova Secret Key neste projeto.

## 1. Criar o banco

1. Abra o projeto no Supabase.
2. Vá em **SQL Editor**.
3. Crie uma nova query.
4. Cole todo o conteúdo de `database.sql`.
5. Clique em **Run**.

O script cria:
- `imports`: histórico das planilhas importadas;
- `sales_items`: vendas normalizadas;
- funções de resumo por período;
- bucket privado `marketplace-files` para arquivos originais;
- regras RLS para exigir usuário autenticado.

## 2. Criar os usuários

Para evitar que qualquer pessoa se cadastre e veja os dados:

1. Vá em **Authentication > Users** no Supabase.
2. Use **Add user / Create user** para criar as contas autorizadas.
3. Em **Authentication > Settings**, desative cadastro público de novos usuários (`Allow new users to sign up`), se estiver habilitado.

Todos os usuários autenticados desta primeira versão enxergam o mesmo conjunto de dados e podem importar/excluir arquivos.

## 3. Testar localmente

Você pode abrir `index.html` no navegador. Para um teste mais fiel, rode um servidor local, por exemplo:

```bash
python -m http.server 8080
```

Depois acesse `http://localhost:8080`.

## 4. Publicar na Vercel

Opção simples:

1. Crie um novo projeto na Vercel.
2. Faça upload desta pasta ou publique via GitHub.
3. Framework Preset: **Other** / site estático.
4. Não é necessário comando de build.
5. Publique.

O arquivo principal é `index.html`.

## 5. Como importar

- Faça login.
- Selecione Data inicial e Data final.
- Envie um ou vários arquivos dos marketplaces desejados.
- Clique em **Processar e salvar**.
- O sistema guarda o arquivo original e as linhas processadas.
- Arquivos repetidos são ignorados pelo hash SHA-256.

Para Amazon, selecione o mesmo período usado na exportação do Business Report antes de importar. O Business Report não contém data por pedido, então o dashboard só inclui essa importação quando o filtro corresponde exatamente ao período salvo.

## 6. Marketplaces suportados

- TikTok
- Mercado Livre
- Shopee
- SHEIN
- Amazon
- Droga Raia
- Magazine Luiza
- Beleza na Web

Droga Raia, Magazine Luiza e Beleza na Web aceitam vários itens na mesma linha e removem `*` dos SKUs.

## 7. Sugestão de compra

A regra atual é:

`Sugestão = teto(total vendido no período × 1,15)`

O estoque enviado na tela é apenas informativo e não reduz a sugestão.

## Permissão de administrador

O sistema considera `luzmakeupadm@gmail.com` como a única conta administradora.

- Administrador: visualiza importação de arquivos e histórico, pode importar e excluir.
- Demais usuários autenticados: visualizam o dashboard e podem exportar relatórios, sem acesso às rotinas de alteração.
- O bloqueio é aplicado também por políticas RLS no Supabase, não apenas na interface.

Se o `database.sql` já foi executado anteriormente, execute-o novamente no SQL Editor para aplicar as novas políticas de administrador. O arquivo é idempotente para as políticas configuradas aqui.
