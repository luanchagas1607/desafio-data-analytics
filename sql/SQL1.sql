


/* =========================================================
   1) PERFIL DEMOGRÁFICO
   1.1) Receita, pedidos, ticket médio por sexo e faixa etária
   ========================================================= */
SELECT
    COALESCE(cl.sexo, 'NÃO INFORMADO') AS sexo,
    CASE
        WHEN cl.data_nascimento IS NULL THEN 'NÃO INFORMADO'
        ELSE
            CASE
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) < 18 THEN '00-17'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 18 AND 24 THEN '18-24'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 25 AND 34 THEN '25-34'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 35 AND 44 THEN '35-44'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 45 AND 54 THEN '45-54'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 55 AND 64 THEN '55-64'
                ELSE '65+'
            END
    END AS faixa_etaria,
    COUNT(DISTINCT v.id_venda) AS pedidos,
    COUNT(DISTINCT v.cliente_id) AS clientes_unicos,
    SUM(v.valor_total) AS receita_total,
    AVG(v.valor_total) AS ticket_medio
FROM vendas v
LEFT JOIN clientes cl
    ON cl.cliente_id = v.cliente_id
GROUP BY
    COALESCE(cl.sexo, 'NÃO INFORMADO'),
    CASE
        WHEN cl.data_nascimento IS NULL THEN 'NÃO INFORMADO'
        ELSE
            CASE
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) < 18 THEN '00-17'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 18 AND 24 THEN '18-24'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 25 AND 34 THEN '25-34'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 35 AND 44 THEN '35-44'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 45 AND 54 THEN '45-54'
                WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 55 AND 64 THEN '55-64'
                ELSE '65+'
            END
    END
ORDER BY receita_total DESC, pedidos DESC;


/* ---------------------------------------------------------
   1.2) Participação % de receita por sexo (janela)
   --------------------------------------------------------- */
SELECT
    sexo,
    receita,
    ROUND(100.0 * receita / SUM(receita) OVER (), 2) AS pct_receita
FROM (
    SELECT
        COALESCE(cl.sexo, 'NÃO INFORMADO') AS sexo,
        SUM(v.valor_total) AS receita
    FROM vendas v
    LEFT JOIN clientes cl
        ON cl.cliente_id = v.cliente_id
    GROUP BY COALESCE(cl.sexo, 'NÃO INFORMADO')
) t
ORDER BY receita DESC;


/* =========================================================
   2) RANKING DE CATEGORIAS
   2.1) Ranking por receita e por quantidade (janelas)
   ========================================================= */
SELECT
    categoria_id,
    nome_categoria,
    receita_total,
    qtd_total,
    linhas_venda,
    DENSE_RANK() OVER (ORDER BY receita_total DESC) AS rank_receita,
    DENSE_RANK() OVER (ORDER BY qtd_total DESC) AS rank_quantidade
FROM (
    SELECT
        v.categoria_id,
        COALESCE(c.nome_categoria, 'NÃO INFORMADO') AS nome_categoria,
        SUM(v.valor_total) AS receita_total,
        SUM(v.quantidade) AS qtd_total,
        COUNT(*) AS linhas_venda
    FROM vendas v
    LEFT JOIN categorias_produtos c
        ON c.categoria_id = v.categoria_id
    GROUP BY v.categoria_id, COALESCE(c.nome_categoria, 'NÃO INFORMADO')
) t
ORDER BY receita_total DESC;


/* ---------------------------------------------------------
   2.2) Participação % por categoria dentro da região
   + ranking por região (janela PARTITION BY)
   --------------------------------------------------------- */
SELECT
    regiao,
    categoria_id,
    nome_categoria,
    receita_categoria,
    ROUND(100.0 * receita_categoria / SUM(receita_categoria) OVER (PARTITION BY regiao), 2) AS pct_na_regiao,
    DENSE_RANK() OVER (PARTITION BY regiao ORDER BY receita_categoria DESC) AS rank_categoria_na_regiao
FROM (
    SELECT
        v.regiao,
        v.categoria_id,
        COALESCE(c.nome_categoria, 'NÃO INFORMADO') AS nome_categoria,
        SUM(v.valor_total) AS receita_categoria
    FROM vendas v
    LEFT JOIN categorias_produtos c
        ON c.categoria_id = v.categoria_id
    GROUP BY v.regiao, v.categoria_id, COALESCE(c.nome_categoria, 'NÃO INFORMADO')
) t
ORDER BY regiao, receita_categoria DESC;


/* =========================================================
   3) SAZONALIDADE
   3.1) Receita por mês (ano/mês) + variação MoM (LAG)
   ========================================================= */
SELECT
    ano,
    mes,
    receita,
    receita_mes_anterior,
    CASE
        WHEN receita_mes_anterior IS NULL OR receita_mes_anterior = 0 THEN NULL
        ELSE ROUND(100.0 * (receita - receita_mes_anterior) / receita_mes_anterior, 2)
    END AS variacao_mom_pct
FROM (
    SELECT
        ano,
        mes,
        receita,
        LAG(receita) OVER (ORDER BY ano, mes) AS receita_mes_anterior
    FROM (
        SELECT
            EXTRACT(YEAR FROM v.data_venda) AS ano,
            EXTRACT(MONTH FROM v.data_venda) AS mes,
            SUM(v.valor_total) AS receita
        FROM vendas v
        GROUP BY
            EXTRACT(YEAR FROM v.data_venda),
            EXTRACT(MONTH FROM v.data_venda)
    ) m
) t
ORDER BY ano, mes;


/* ---------------------------------------------------------
   3.2) Sazonalidade por mês do ano (independente do ano)
   --------------------------------------------------------- */
SELECT
    EXTRACT(MONTH FROM v.data_venda) AS mes,
    SUM(v.valor_total) AS receita_total,
    COUNT(DISTINCT v.id_venda) AS pedidos,
    AVG(v.valor_total) AS ticket_medio
FROM vendas v
GROUP BY EXTRACT(MONTH FROM v.data_venda)
ORDER BY receita_total DESC;


/* =========================================================
   4) TENDÊNCIA POR REGIÃO
   4.1) Receita mensal por região + ranking por mês
   ========================================================= */
SELECT
    regiao,
    ano,
    mes,
    receita,
    DENSE_RANK() OVER (PARTITION BY ano, mes ORDER BY receita DESC) AS rank_regiao_no_mes
FROM (
    SELECT
        v.regiao,
        EXTRACT(YEAR FROM v.data_venda) AS ano,
        EXTRACT(MONTH FROM v.data_venda) AS mes,
        SUM(v.valor_total) AS receita
    FROM vendas v
    GROUP BY
        v.regiao,
        EXTRACT(YEAR FROM v.data_venda),
        EXTRACT(MONTH FROM v.data_venda)
) t
ORDER BY ano, mes, receita DESC;


/* ---------------------------------------------------------
   4.2) Média móvel 3 meses por região (janela)
   Observação: cria um "ano_mes_ord" para ordenar corretamente.
   --------------------------------------------------------- */
SELECT
    regiao,
    ano,
    mes,
    receita,
    ROUND(
        AVG(receita) OVER (
            PARTITION BY regiao
            ORDER BY ano_mes_ord
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ),
        2
    ) AS media_movel_3m
FROM (
    SELECT
        v.regiao,
        EXTRACT(YEAR FROM v.data_venda) AS ano,
        EXTRACT(MONTH FROM v.data_venda) AS mes,
        SUM(v.valor_total) AS receita,
        (EXTRACT(YEAR FROM v.data_venda) * 100 + EXTRACT(MONTH FROM v.data_venda)) AS ano_mes_ord
    FROM vendas v
    GROUP BY
        v.regiao,
        EXTRACT(YEAR FROM v.data_venda),
        EXTRACT(MONTH FROM v.data_venda)
) t
ORDER BY regiao, ano, mes;


/* =========================================================
   5) RELAÇÃO IDADE x CATEGORIA
   5.1) Matriz faixa etária x categoria
   ========================================================= */
SELECT
    faixa_etaria,
    categoria_id,
    nome_categoria,
    COUNT(DISTINCT id_venda) AS pedidos,
    SUM(valor_total) AS receita_total,
    AVG(valor_total) AS ticket_medio
FROM (
    SELECT
        v.id_venda,
        v.valor_total,
        v.categoria_id AS categoria_id,
        COALESCE(c.nome_categoria, 'NÃO INFORMADO') AS nome_categoria,
        CASE
            WHEN cl.data_nascimento IS NULL THEN 'NÃO INFORMADO'
            ELSE
                CASE
                    WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) < 18 THEN '00-17'
                    WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 18 AND 24 THEN '18-24'
                    WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 25 AND 34 THEN '25-34'
                    WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 35 AND 44 THEN '35-44'
                    WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 45 AND 54 THEN '45-54'
                    WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 55 AND 64 THEN '55-64'
                    ELSE '65+'
                END
        END AS faixa_etaria
    FROM vendas v
    LEFT JOIN clientes cl
        ON cl.cliente_id = v.cliente_id
    LEFT JOIN categorias_produtos c
        ON c.categoria_id = v.categoria_id
) b
GROUP BY faixa_etaria, categoria_id, nome_categoria
ORDER BY faixa_etaria, receita_total DESC;


/* ---------------------------------------------------------
   5.2) Top 1 categoria por faixa etária (ROW_NUMBER)
   --------------------------------------------------------- */
SELECT
    faixa_etaria,
    categoria_id,
    nome_categoria,
    receita_total,
    pedidos
FROM (
    SELECT
        faixa_etaria,
        categoria_id,
        nome_categoria,
        receita_total,
        pedidos,
        ROW_NUMBER() OVER (PARTITION BY faixa_etaria ORDER BY receita_total DESC) AS rn
    FROM (
        SELECT
            CASE
                WHEN cl.data_nascimento IS NULL THEN 'NÃO INFORMADO'
                ELSE
                    CASE
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) < 18 THEN '00-17'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 18 AND 24 THEN '18-24'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 25 AND 34 THEN '25-34'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 35 AND 44 THEN '35-44'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 45 AND 54 THEN '45-54'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 55 AND 64 THEN '55-64'
                        ELSE '65+'
                    END
            END AS faixa_etaria,
            v.categoria_id,
            COALESCE(c.nome_categoria, 'NÃO INFORMADO') AS nome_categoria,
            SUM(v.valor_total) AS receita_total,
            COUNT(DISTINCT v.id_venda) AS pedidos
        FROM vendas v
        LEFT JOIN clientes cl
            ON cl.cliente_id = v.cliente_id
        LEFT JOIN categorias_produtos c
            ON c.categoria_id = v.categoria_id
        GROUP BY
            CASE
                WHEN cl.data_nascimento IS NULL THEN 'NÃO INFORMADO'
                ELSE
                    CASE
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) < 18 THEN '00-17'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 18 AND 24 THEN '18-24'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 25 AND 34 THEN '25-34'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 35 AND 44 THEN '35-44'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 45 AND 54 THEN '45-54'
                        WHEN (EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM cl.data_nascimento)) BETWEEN 55 AND 64 THEN '55-64'
                        ELSE '65+'
                    END
            END,
            v.categoria_id,
            COALESCE(c.nome_categoria, 'NÃO INFORMADO')
    ) agg
) ranked
WHERE rn = 1
ORDER BY faixa_etaria;
