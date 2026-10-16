-- =============================================================================
-- Diagnóstico: campo "area" (var_ramo_atv) duplicando no Ranking QD Integrado
-- Origem do campo: SEBIVIEW_f38e1031d92e1f76bb59 (tabela materializada da
--                  análise "CO005Aux" - grid CO005AUX0 / ficha CO00101)
-- Banco: PostgreSQL
-- -----------------------------------------------------------------------------
-- O filtro "status = Ativo" NÃO está neste SQL: está na definição da análise
-- no SE Suite. Estas consultas não corrigem o filtro - elas provam se ele está
-- entregando o grão esperado (uma linha por tx006) e apontam onde corrigir.
-- =============================================================================

-- 1) Escala do problema: quais códigos devolvem mais de uma linha / mais de uma área
SELECT
    TRIM(tx006)                                    AS cod_fornecedor,
    COUNT(*)                                       AS linhas,
    COUNT(DISTINCT TRIM(var_ramo_atv))             AS areas_distintas,
    STRING_AGG(DISTINCT '[' || COALESCE(TRIM(var_ramo_atv), '<NULL>') || ']', ' | ')
                                                   AS valores
FROM SEBIVIEW_f38e1031d92e1f76bb59
GROUP BY TRIM(tx006)
HAVING COUNT(*) > 1
ORDER BY areas_distintas DESC, linhas DESC;

-- 2) Grão real da view para um código específico.
--    Olhe se o status e o identificador da ficha aparecem como coluna.
--    Se NÃO aparecem, inclua-os na análise: sem eles não há como distinguir
--    "filtro furado" de "duas fichas realmente ativas".
SELECT * FROM SEBIVIEW_f38e1031d92e1f76bb59
WHERE TRIM(tx006) = '<CODIGO>';

-- 3) Quais colunas a análise expõe hoje
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name = 'sebiview_f38e1031d92e1f76bb59'
ORDER BY ordinal_position;

-- 4) Diferença invisível? (espaço no fim, caixa, acento, NULL vs '')
SELECT
    tx006,
    var_ramo_atv,
    LENGTH(var_ramo_atv) AS tam,
    MD5(var_ramo_atv)    AS hash,
    COUNT(*)             AS linhas
FROM SEBIVIEW_f38e1031d92e1f76bb59
WHERE TRIM(tx006) = '<CODIGO>'
GROUP BY 1, 2, 3, 4;

-- 5) Confronto com a tabela viva: quantas fichas realmente estão Ativas?
--    Confirme o nome real da tabela e da coluna de status antes de rodar.
--    Se a tabela viva mostra UMA ficha ativa e a view mostra duas:
--    materialização defasada ou filtro da análise mal agrupado (AND/OR).
--    Se a tabela viva mostra DUAS ativas: o filtro está certo e o dado não -
--    tratar no SE Suite (inativar a ficha antiga) ou revisar a chave do join.
-- SELECT oid, <campo_codigo>, <campo_status>, <campo_data>
-- FROM DYNCO00101
-- WHERE TRIM(<campo_codigo>) = '<CODIGO>'
-- ORDER BY oid DESC;

-- 6) Impacto a jusante: a duplicação não repete só a linha da área.
--    Rode o nível "a" da query do ranking antes e depois da correção.
--    Se a contagem cair, as médias móveis de 12 meses e os rank_*_area
--    estavam contando meses repetidos.
