-- =============================================================================
-- Correção do join da área (var_ramo_atv) no Ranking QD Integrado
-- Local na query: nível "a" mais interno, logo após o INNER JOIN DYNCO003 QD
-- Banco: PostgreSQL
-- -----------------------------------------------------------------------------
-- Isto NÃO substitui a correção do filtro "status Ativo" na análise CO005Aux
-- do SE Suite. É a garantia de que a query não multiplica linhas enquanto a
-- origem puder devolver mais de uma ficha por fornecedor - invariante da
-- query, não confiança na origem.
-- =============================================================================

-- ANTES (multiplica a linha do fornecedor quando a view traz 2 áreas):
--
--     left join (select distinct
--                     tx006, var_ramo_atv
--                 from SEBIVIEW_f38e1031d92e1f76bb59
--             ) area  --CO005Aux
--         on qd.gcod = area.tx006
--
-- Por que o DISTINCT não resolve: ele é sobre o PAR (tx006, var_ramo_atv).
-- Dois valores diferentes de var_ramo_atv para o mesmo tx006 sobrevivem a ele.
-- E o SELECT DISTINCT do nível de cima também não resolve, porque as window
-- functions (rank_mensal, ROW_NUMBER, parametro) são calculadas ANTES dele e
-- saem com valores diferentes em cada linha duplicada.


-- DEPOIS - opção A: sem coluna de data/ordenação disponível na análise.
-- Determinística, mas a escolha da área é arbitrária (maior valor alfabético).
left join (
    SELECT
        TRIM(tx006)                        AS tx006,
        MAX(TRIM(var_ramo_atv))            AS var_ramo_atv,
        COUNT(DISTINCT TRIM(var_ramo_atv)) AS qtd_areas   -- sentinela
    FROM SEBIVIEW_f38e1031d92e1f76bb59
    WHERE COALESCE(TRIM(var_ramo_atv), '') <> ''
    GROUP BY TRIM(tx006)
) area  --CO005Aux
    on TRIM(qd.gcod) = area.tx006


-- DEPOIS - opção B (preferível): depois de incluir na análise o status, o
-- identificador da ficha e a data. Aí a escolha deixa de ser arbitrária.
-- left join (
--     SELECT tx006, var_ramo_atv, qtd_areas
--     FROM (
--         SELECT
--             TRIM(tx006)        AS tx006,
--             TRIM(var_ramo_atv) AS var_ramo_atv,
--             COUNT(*) OVER (PARTITION BY TRIM(tx006))      AS qtd_areas,
--             ROW_NUMBER() OVER (
--                 PARTITION BY TRIM(tx006)
--                 ORDER BY <campo_data> DESC, <oid_ficha> DESC
--             ) AS rn
--         FROM SEBIVIEW_f38e1031d92e1f76bb59
--         WHERE COALESCE(TRIM(var_ramo_atv), '') <> ''
--           AND TRIM(<campo_status>) = 'Ativo'   -- redundante de propósito
--     ) z
--     WHERE rn = 1
-- ) area  --CO005Aux
--     on TRIM(qd.gcod) = area.tx006

-- Notas:
-- 1) O TRIM nos dois lados do ON também resolve o problema oposto, que às
--    vezes aparece junto: area vindo NULL por CHAR com espaços de preenchimento.
-- 2) Carregue qtd_areas até o nível de cima e confira periodicamente
--    (qtd_areas > 1). Se a análise voltar a duplicar, você vê na hora em vez
--    de descobrir meses depois por um ranking errado.
-- 3) Repetir o filtro de status no SQL é defesa em profundidade: se a
--    materialização atrasar, a query não propaga ficha inativa.
