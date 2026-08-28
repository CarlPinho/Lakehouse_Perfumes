# Prompt 2 · Bronze — dez tabelas em um comando

**Entrega:** as 10 tabelas Delta da bronze, criadas por código, e a segunda
tarefa no job. **Deploy nº 2.**

> **A resposta direta à noite de ontem.** Eles subiram tabela por tabela na
> interface, uma de cada vez. Hoje é uma função e uma lista.

---

## O que mostrar antes

Duas telas, e a segunda é a que vende a decisão da bronze.

**1 · A bronze está vazia. Só existe o controle de chegada.**

```sql
SHOW TABLES IN lakehouse_rotaperfume.bronze;
-- só _raw_arquivos, do prompt 1. Nenhuma tabela de dado ainda.
```

**2 · O que acontece se você deixar o Spark adivinhar o tipo**

Rode as duas leituras do MESMO arquivo, uma ao lado da outra:

```sql
-- (a) tudo texto, que é como a bronze vai guardar
SELECT cliente_id, cnpj, data_cadastro
FROM read_files('/Volumes/lakehouse_rotaperfume/bronze/raw/crm/clientes.csv',
                format => 'csv', header => true)
WHERE cnpj LIKE '0%' LIMIT 5;

-- (b) o mesmo arquivo com inferência de tipo ligada
SELECT typeof(cnpj) AS tipo_do_cnpj, cliente_id, cnpj, data_cadastro
FROM read_files('/Volumes/lakehouse_rotaperfume/bronze/raw/crm/clientes.csv',
                format => 'csv', header => true, inferColumnTypes => true)
WHERE cliente_id IN (SELECT cliente_id FROM read_files(
        '/Volumes/lakehouse_rotaperfume/bronze/raw/crm/clientes.csv',
        format => 'csv', header => true) WHERE cnpj LIKE '0%')
LIMIT 5;
```

Em (b) o CNPJ virou número e **perdeu o zero da frente**. São 309 clientes cujo
documento fica errado para sempre — e ninguém recebe erro nenhum. Essa é a
justificativa inteira do `inferColumnTypes => false` do prompt.

**A pergunta para a sala:** *"quem aqui já viu CNPJ ou CEP virar número numa
planilha? E quem descobriu isso no mesmo dia?"*

---

**Enquanto ele trabalha, você explica:**

- **Por que a bronze preserva a sujeira.** Se o Spark adivinhar o tipo, ele
  converte `15/10/2025` em nulo e apaga os zeros à esquerda de 309 CNPJs. A
  sujeira sumiria antes de vocês verem — e vocês nunca saberiam que ela existiu.
- **`inferColumnTypes => false` não é preguiça, é decisão.** Tudo entra como
  texto de propósito. Converter é trabalho da silver, feito sabendo o que se faz.
- **Metadado técnico.** `_ingerido_em` e `_arquivo_origem` respondem as duas
  primeiras perguntas de qualquer investigação: *quando isso entrou* e *de qual
  arquivo veio*.
- **Escreva a ingestão uma vez.** Dez tabelas, uma função, uma lista. Se amanhã
  o ERP mandar a décima primeira, é uma linha.

---

## O prompt

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A camada raw já está no Volume e conferida. Agora crie a bronze.

1. src/bronze/ingestao.py
   Notebook Python serverless (`# Databricks notebook source`) que lê os 10
   CSVs de /Volumes/{catalog}/bronze/raw/{sistema}/{tabela}.csv e grava
   {catalog}.bronze.{tabela} em Delta, modo overwrite.

   REGRAS DA BRONZE — nenhuma limpeza, nenhuma conversão de tipo:
   - leia TUDO como string. Nada de inferSchema.
   - os CSVs são CRLF e têm header. Não use multiLine.
   - adicione só duas colunas: _ingerido_em (timestamp) e _arquivo_origem.
   - escreva a função de ingestão UMA vez e itere sobre a lista das 10 tabelas.
     Não repita bloco por tabela.
   - ao final, imprima uma tabela com o nome e a contagem de linhas de cada uma,
     e compare com o que bronze._raw_arquivos registrou no prompt anterior:
     linhas da tabela = linhas do arquivo menos o header. Se divergir, falhe.

   Adicione COMMENT em cada tabela dizendo de qual sistema de origem ela veio.

2. resources/pipeline.job.yml
   Acrescente a tarefa bronze_ingestao, com depends_on: raw_conferencia.
   A ordem é o conteúdo: se a conferência falhar, a bronze não roda.

3. Rode e me mostre a saída:
   databricks bundle deploy --target dev --profile projeto-dados-ia
   databricks bundle run rotaperfume_pipeline --target dev --profile projeto-dados-ia

CONTAGENS ESPERADAS (do gerador com seed 42 — se divergir, o erro é seu):
  produtos 292 · pedidos 28.729 · itens_pedido 197.724 · pagamentos 27.772
  estoque 8.400 · clientes 3.040 · vendedores 42 · carteira 3.637
  oportunidades 5.979 · visitas 37.936     total: 313.551

Não limpe nada. A sujeira é o conteúdo do próximo prompt.
```

---

## Como verificar a feature

**1 · As 10 tabelas existem, e a contagem bate com o arquivo de origem**

```sql
SHOW TABLES IN lakehouse_rotaperfume.bronze;   -- 10 + _raw_arquivos

WITH contagem AS (
  SELECT 'produtos'     AS tabela, COUNT(*) AS linhas FROM lakehouse_rotaperfume.bronze.produtos
  UNION ALL SELECT 'pedidos',      COUNT(*) FROM lakehouse_rotaperfume.bronze.pedidos
  UNION ALL SELECT 'itens_pedido', COUNT(*) FROM lakehouse_rotaperfume.bronze.itens_pedido
  UNION ALL SELECT 'pagamentos',   COUNT(*) FROM lakehouse_rotaperfume.bronze.pagamentos
  UNION ALL SELECT 'estoque',      COUNT(*) FROM lakehouse_rotaperfume.bronze.estoque
  UNION ALL SELECT 'clientes',     COUNT(*) FROM lakehouse_rotaperfume.bronze.clientes
  UNION ALL SELECT 'vendedores',   COUNT(*) FROM lakehouse_rotaperfume.bronze.vendedores
  UNION ALL SELECT 'carteira',     COUNT(*) FROM lakehouse_rotaperfume.bronze.carteira
  UNION ALL SELECT 'oportunidades',COUNT(*) FROM lakehouse_rotaperfume.bronze.oportunidades
  UNION ALL SELECT 'visitas',      COUNT(*) FROM lakehouse_rotaperfume.bronze.visitas
)
SELECT c.tabela, c.linhas AS na_tabela, r.linhas AS no_arquivo,
       c.linhas = r.linhas AS bate
FROM contagem c
JOIN lakehouse_rotaperfume.bronze._raw_arquivos r ON r.arquivo = c.tabela || '.csv'
ORDER BY c.linhas DESC;
```

**Coluna `bate` tem que ser `true` nas 10 linhas.** O total é 313.551 — o mesmo
número do prompt 1. Se uma linha der `false`, o CSV foi lido errado (quase
sempre `multiLine` ligado ou separador trocado), e é melhor descobrir agora.

**2 · Tudo entrou como texto — de propósito**

```sql
DESCRIBE TABLE lakehouse_rotaperfume.bronze.pedidos;
-- todas as colunas de negócio em STRING; só _ingerido_em é TIMESTAMP
```

**3 · O metadado técnico responde "de onde veio" e "quando entrou"**

```sql
SELECT _arquivo_origem, MIN(_ingerido_em) AS ingerido_em, COUNT(*) AS linhas
FROM lakehouse_rotaperfume.bronze.itens_pedido
GROUP BY _arquivo_origem;
```

**4 · A sujeira foi PRESERVADA — e é a deixa literal do prompt 3**

```sql
SELECT
  COUNT(*)                                                          AS clientes,
  COUNT(*) FILTER (WHERE cnpj LIKE '%.%')                           AS cnpj_pontuado,
  COUNT(*) FILTER (WHERE cnpj <> trim(cnpj))                        AS cnpj_com_espaco,
  COUNT(*) FILTER (WHERE regexp_replace(trim(cnpj),'[^0-9]','') LIKE '0%') AS cnpj_zero_a_esquerda,
  COUNT(*) FILTER (WHERE data_cadastro LIKE '%/%')                  AS data_formato_br,
  COUNT(*) FILTER (WHERE razao_social = upper(razao_social))        AS razao_caixa_alta
FROM lakehouse_rotaperfume.bronze.clientes;
```

| O que aparece | Valor | Onde isso é resolvido |
|---|---|---|
| Clientes na bronze | **3.040** | prompt 3 · dedup → 3.000 |
| CNPJ pontuado | **1.111** | prompt 3 · `regexp_replace` |
| CNPJ com espaço | **223** | prompt 3 · `trim` |
| CNPJ com zero à esquerda | **309** | prompt 3 · `lpad`, e nunca CAST para número |
| Data em dd/MM/yyyy | 12% da tabela | prompt 3 · `try_to_date` duplo |

E a tela que abre o próximo prompt:

```sql
SELECT cliente_id, cnpj, razao_social, data_cadastro
FROM lakehouse_rotaperfume.bronze.clientes
WHERE cnpj LIKE '%.%' OR cnpj <> trim(cnpj)
LIMIT 10;
```

**Aponte na tela:** o CNPJ em três formatos e a razão social em CAIXA ALTA.

**5 · A prova de que a bronze não conserta nada — o erro de propósito**

```sql
-- "me dá os cinco maiores pedidos" — direto da bronze
SELECT pedido_id, valor_total
FROM lakehouse_rotaperfume.bronze.pedidos
ORDER BY valor_total DESC
LIMIT 5;
-- o "maior" pedido é o que COMEÇA com 9: valor_total é texto, e texto
-- ordena em ordem alfabética: '987.50' vem antes de '10240.00'.

-- e a mesma pergunta com a conversão que a silver vai fazer amanhã
SELECT pedido_id, CAST(valor_total AS DECIMAL(18,2)) AS valor
FROM lakehouse_rotaperfume.bronze.pedidos
ORDER BY valor DESC
LIMIT 5;
```

> *"As duas listas são diferentes, e nenhuma das duas deu erro. Isso não é
> limitação da bronze, é o contrato dela: ela responde 'o que o ERP mandou'.
> Quem responde 'quanto a gente vendeu' é a próxima camada — e é lá que a
> conversão fica escrita uma vez, para todo mundo."*

---

## Fala de aula

> *"Ontem isso levou vocês uns quinze minutos de clique. Agora foram noventa
> segundos — e olha o que eu ganhei junto: está no Git, roda de novo igual, e
> qualquer um da equipe consegue repetir sem me perguntar nada.*
>
> *Agora repara nessa coluna aqui. Três formatos de CNPJ na mesma tabela. Eu
> podia ter limpado na entrada, e ia parecer mais bonito. Mas aí, quando o
> número desse errado lá na frente, eu não teria como saber se o erro veio da
> origem ou da minha limpeza. A bronze é a prova. Ela nunca se edita."*


---

## Se der errado ao vivo

| Sintoma | Causa | Correção em um prompt |
|---|---|---|
| A contagem de `visitas` não bate | O número certo é **37.936**, não 38.112 | Confira contra `bronze._raw_arquivos`, não contra o PRD |
| Aparece uma coluna `_rescued_data` | O leitor de arquivo do Databricks cria essa coluna sozinho | *"Descarte com `SELECT * EXCEPT (_rescued_data)`."* Passar `rescuedDataColumn => ''` **não** desliga: cria uma coluna de nome vazio e o CREATE TABLE quebra |
| O CNPJ perdeu os zeros à esquerda | Alguém deixou o Spark inferir tipo | `inferSchema=False`. São 309 registros que somem calados |
| Data virou nulo na bronze | Mesma causa | A bronze não converte nada. Tudo é texto |

**Tempo medido:** ~50s de deploy, ~1min40 de execução das duas tarefas.