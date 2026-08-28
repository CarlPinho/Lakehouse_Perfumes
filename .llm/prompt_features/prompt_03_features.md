# Prompt 3 · A fila e o agente

**Slides que acompanham:** 37 a 45 (divisor *"Os 200"*, batch ou tempo real, o
gap que mata projetos, as ferramentas do agente, a resposta para o diretor, o
antes e o depois, o arco de três noites, a frase da noite).

**Entrega:** `gold.fila_semanal` — as 200 linhas com nome, motivo em português
e o que oferecer — mais as quatro ferramentas que o agente consulta.
**Deploy nº 3 da noite.**

> Score não é decisão. `0,8412` não é uma ação. Este prompt é o último metro:
> o que separa o modelo que roda do modelo que alguém usa.

---

## O ambiente, conferido hoje

Rodado contra `lakehouse_rotaperfume` no workspace. **Tudo o que este prompt
usa já existe** — nenhuma fonte precisa ser criada antes:

| Tabela | O que este prompt lê dela |
|---|---|
| `gold.score_propensao` | criada no prompt 2 — 2.816 clientes com nota |
| `gold.features_cliente` | as features, para escrever o motivo |
| `gold.dim_cliente` | `razao_social`, `cidade`, `uf` |
| `silver.carteira` | `vigente` e `orfao_vendedor_desligado` — os dois são filtro |
| `silver.vendedores` | `nome` e `ativo`. A carteira só tem `vendedor_id` |
| `silver.estoque` | snapshot semanal: `data_snapshot`, `saldo`, `ruptura` |

Não há nenhuma função SQL em `gold` — as quatro ferramentas nascem aqui.

O job está com **12 tarefas** e o `bundle deploy` passa limpo. A pasta
`rotaperfume/src/ml/` **não existe** — ela está no `.gitignore` para nascer
vazia toda vez, e é isso que faz os prompts terem o que construir.

> **No deploy, se aparecer pedido de confirmação para APAGAR O DASHBOARD:
> recuse e me chame.** O dashboard é da noite 2 e a chave do recurso
> (`dashboard_comercial`) não pode ser renomeada — trocar a chave faz o bundle
> apagar e recriar, com URL nova. **Nunca use `--auto-approve` aqui.**

---

## O que mostrar antes

**1 · O score, cru, como ele sai do modelo**

```sql
SELECT cliente_id, ROUND(score, 4) AS score, faixa
FROM lakehouse_rotaperfume.gold.score_propensao
ORDER BY score DESC LIMIT 5;
```

> *"Está certíssimo e é inútil. Entregue isso para o vendedor e ele volta a
> ligar pela intuição na segunda-feira. Já vi acontecer com modelo de AUC 0,89
> rodando há dois anos."*

**2 · A pergunta que decide o desenho da tabela**

Faça para a sala antes de colar o prompt:

> *"São 200 ligações e 42 vendedores. Dou 5 para cada um, ou dou os 200
> melhores da base inteira?"*

A resposta quase sempre é "5 para cada, é mais justo". E aí:

> *"Justo com quem? Se a carteira do João está quente e a do Pedro está fria,
> a cota igual obriga o João a deixar cliente quente na mesa para o Pedro
> ligar para cliente frio."*

**A fila é global; a capacidade é que é por pessoa.** É por isso que a tabela
sai com `ORDER BY score DESC LIMIT 200` e não com cota por vendedor.

---

**Enquanto ele trabalha, você explica:**

- **O último metro é onde os projetos morrem.** Dado, modelo, score na
  tabela — e ninguém liga. O gargalo nunca é o algoritmo.
- **Motivo em português não é enfeite.** É o que faz o vendedor confiar
  quando o modelo acerta, e o que permite entender **por que** quando ele
  erra, em vez de simplesmente parar de usar.
- **Agente não inventa: ele consulta.** As quatro ferramentas são consultas ao
  Unity Catalog, com nome e contrato. Agente sem dado organizado por trás é
  chute com sotaque — e as três noites anteriores foram construir esse dado.
- **A carteira entra aqui.** O score é por cliente; a ligação é por vendedor.
  `silver.carteira` é quem faz a ponte, e é por isso que ela foi limpa na
  noite 2.

---

## O prompt

```
Continue o mesmo bundle. gold.score_propensao tem os 3.000 clientes com nota.

Crie src/ml/13-fila.sql — um arquivo SQL para rodar como sql_task.

1. A TABELA DA SEMANA: gold.fila_semanal

   As fontes e como juntar:
     gold.score_propensao   cliente_id, score, faixa, versao
     gold.features_cliente  as features, para escrever o motivo
     gold.dim_cliente       razao_social, cidade, uf
     silver.carteira        cliente_id -> vendedor_id.
                            FILTRE por vigente = true, e descarte
                            orfao_vendedor_desligado = true: vendedor
                            desligado não recebe ligação para fazer.
     silver.vendedores      vendedor_id -> nome. A carteira só tem o id.

   A ORDEM DAS OPERAÇÕES IMPORTA, e é o erro mais fácil de cometer aqui:

     1º  junte a carteira e DESCARTE quem não é elegível
         (sem carteira vigente, ou vendedor desligado)
     2º  ORDER BY score DESC LIMIT 200
     3º  ROW_NUMBER() OVER (PARTITION BY vendedor ORDER BY score DESC)

   Se o descarte vier DEPOIS do LIMIT, a fila sai com ~172 linhas em vez de
   200 — seis dos 42 vendedores estão desligados e levam junto os clientes
   deles — e o teste 1 quebra o job. Filtrando antes, sobram 2.393 clientes
   elegíveis e a fila fecha em 200 exatas, distribuídas em ~36 vendedores.
   Não use cota igual por vendedor: a carteira de um é mais quente que a do
   outro, e cota fixa obriga a gastar ligação com cliente frio.

   Colunas: vendedor, ordem, cliente_id, razao_social, cidade, uf, score,
   faixa, ticket_medio, e duas colunas escritas para gente ler:

   motivo — uma frase em português montada com CASE WHEN sobre as features,
   com os números reais do cliente dentro, via FORMAT_NUMBER:
     atraso_relativo > 3   -> 'Compra a cada N dias e está há M sem pedido.
                               Risco de perder para o concorrente.'
     atraso_relativo > 1.5 -> 'Está N vezes mais atrasado que o ritmo dele.'
     comprou_lancamento    -> 'Comprou lançamento recente. Alta chance de
                               repetir.'
     valor_total no topo   -> 'Cliente grande, R$ X no ano. Manter próximo.'
     ELSE                  -> 'Dentro do ritmo. Contato de manutenção.'
   O ELSE é obrigatório: motivo nulo quebra o teste 2.

   sugestao — o SKU mais comprado pelo cliente na marca preferida dele que
   ele NÃO comprou nos últimos 90 dias, com o saldo vindo do snapshot mais
   recente de silver.estoque (a tabela é um snapshot semanal: pegue
   max(data_snapshot) por sku, não a tabela inteira).

2. AS QUATRO FERRAMENTAS, como funções SQL no Unity Catalog, cada uma com
   COMMENT em português dizendo para que serve — é o COMMENT que o agente lê:

   gold.priorizar_carteira(p_vendedor STRING, p_quantos INT)
     RETURNS TABLE — a fatia da fila_semanal daquele vendedor, em ordem
   gold.contexto_cliente(p_cliente_id INT)
     RETURNS TABLE — histórico, ticket médio, marcas preferidas, última compra
   gold.sugerir_produtos(p_cliente_id INT)
     RETURNS TABLE — o que ele compra e parou de comprar nos últimos 90 dias
   gold.checar_disponibilidade(p_sku STRING)
     RETURNS TABLE — saldo e ruptura no snapshot mais recente

   Prefixe TODO parâmetro com p_: parâmetro com o mesmo nome de uma coluna
   fica ambíguo dentro do corpo da função e o CREATE falha.
   cliente_id é INT no catálogo, não BIGINT.

3. TRÊS TESTES QUE QUEBRAM O JOB, no mesmo padrão raise_error() dentro de
   CASE WHEN que a noite 2 usa:
   - a fila tem exatamente 200 linhas
   - nenhuma linha com motivo nulo ou vazio
   - nenhum score fora do intervalo [0, 1]

A ORDEM DOS PASSOS 4 E 5 IMPORTA, e é o erro mais fácil de cometer aqui: o
Genie RECUSA referenciar tabela que ainda não existe. Se o deploy do Genie
acontecer antes de fila_semanal ser criada, ele morre com
"PERMISSION_DENIED ... Table ... does not exist" — e a mensagem não diz que o
problema é ordem. Crie a tabela primeiro (rode a tarefa, ou o SQL pelo
scripts/run_sql.py), e só então faça o deploy com o Genie atualizado.

4. Acrescente uma PÁGINA ao dashboard da noite 2
   (resources/dashboard-comercial.lvdash.json), chamada "Fila da semana":
   um filtro de vendedor e a tabela com ordem, cliente, cidade, nota, faixa,
   motivo e sugestão. É onde o vendedor vai ver a lista — sem isso, os 200
   ficam numa tabela que ele nunca abre.

   NÃO renomeie a chave do recurso do dashboard: trocar a chave faz o bundle
   apagar e recriar, com URL nova.

5. Some gold.fila_semanal e gold.score_propensao ao Genie Space que já existe
   em resources/ (genie.genie_space.yml e o comercial.geniespace.json), com a
   instrução:
   "Use sempre as tabelas e funções deste espaço. Nunca invente número,
    nome de cliente ou quantidade de estoque."

COMMENT em português na TABELA (a auditoria quebra o job sem ele) e TAMBÉM em
todas as colunas de fila_semanal: é o comentário de coluna que o Genie lê para
responder sem inventar. Nas funções, o COMMENT é o que diz ao agente quando
usar cada uma.

Registre a tarefa ml_fila em resources/pipeline.job.yml, depois de ml_modelo,
e faça o deploy.

NÃO rode o job inteiro para testar: rode só a tarefa nova, com
bash scripts/rodar-tarefa.sh <perfil> ml_fila — o job completo leva 3m30 e
a tarefa sozinha 35s.
```


---

## Como rodar, e por que NÃO o job inteiro

> **⚠️ Se a tarefa falhar com `Unable to access the notebook`:** a pasta
> `src/ml/` está no `.gitignore` (para nascer vazia toda vez) e **o bundle
> respeita o `.gitignore` ao sincronizar**. O `databricks.yml` já traz o
> `sync.include` que resolve isso — se alguém apagar esse bloco, o notebook
> nunca chega ao workspace, e a mensagem de erro não menciona gitignore
> nenhum.

```bash
bash scripts/rodar-tarefa.sh <perfil> ml_fila
```

| | Tempo |
|---|---|
| `bundle run rotaperfume_pipeline` — as 13 tarefas | **~3m30** |
| só a tarefa nova | **~35s** |

Cada tarefa serverless paga o próprio tempo de partida, e o job inteiro paga
treze vezes. **Ao vivo, é a diferença entre a sala esperar três minutos e meio
a cada tentativa, ou trinta segundos.**

O job completo continua valendo — **uma vez, no fim**, quando a tarefa já
funciona e você quer mostrar o DAG inteiro verde. Não como forma de testar.

---

## Como verificar a feature

**1 · A resposta para o diretor, na tela**

```sql
SELECT vendedor, ordem, razao_social, ROUND(score, 2) AS score, motivo
FROM lakehouse_rotaperfume.gold.fila_semanal
WHERE vendedor = (SELECT vendedor FROM lakehouse_rotaperfume.gold.fila_semanal
                  GROUP BY vendedor ORDER BY COUNT(*) DESC LIMIT 1)
ORDER BY ordem;
```

A lista de quem recebeu mais contatos, com nome e motivo. **É o slide *A resposta para o diretor* saindo do banco.** Leia a
primeira em voz alta e pare.

**2 · A conta fecha, e a distribuição conta uma história**

```sql
SELECT COUNT(DISTINCT vendedor) AS vendedores,
       COUNT(*)                 AS ligacoes
FROM lakehouse_rotaperfume.gold.fila_semanal;

-- quem recebeu muito e quem recebeu pouco
SELECT vendedor, COUNT(*) AS ligacoes, ROUND(AVG(score), 3) AS score_medio
FROM lakehouse_rotaperfume.gold.fila_semanal
GROUP BY vendedor ORDER BY ligacoes DESC;
```

**200 contatos em 35 vendedores, de 1 a 12 ligações cada.** São 36 e não 42
porque seis vendedores estão desligados com carteira ainda vinculada — a nona
das dez sujeiras da noite 2, aparecendo de novo. O vendedor do topo não é o
melhor vendedor — é o que tem a carteira mais quente. E isso é uma
conversa de negócio que só existe porque agora tem número.

**3 · A ferramenta, chamada como o agente chamaria**

```sql
SELECT * FROM lakehouse_rotaperfume.gold.priorizar_carteira('Ana Souza', 5);
```

> *"Isso não é um endpoint, não é um framework e não tem prompt nenhum. É uma
> função no catálogo, com contrato e comentário. O agente só sabe chamar."*

**4 · O Genie, que é a interface**

Abra o Genie Space e pergunte, com as palavras do vendedor:

> *"Quem eu ligo essa semana?"*

Depois peça o que só o dado responde:

> *"Por que a Perfumaria Aurora está no topo da minha lista?"*

**Mostre o SQL que o Genie gerou.** É a diferença entre agente e chute: a
resposta tem query embaixo.

---

## Se der errado

| Sintoma | Causa | Saída |
|---|---|---|
| `PERMISSION_DENIED ... Table 'fila_semanal' does not exist` no deploy | o Genie foi atualizado antes de a tabela existir | crie a tabela primeiro, depois deploye. **Aconteceu no ensaio** |
| `INVALID_LIMIT_LIKE_EXPRESSION` no `CREATE FUNCTION` | `LIMIT p_quantos` — o Databricks exige LIMIT constante | filtre por `ordem <= p_quantos`, que a fila já vem numerada. **Aconteceu no ensaio** |
| `data_sources.tables must be sorted by identifier` | o Genie exige as tabelas em ordem alfabética | ordene a lista — e as `column_configs` de cada uma também |
| `text_instructions must contain at most one item` | o Genie aceita **uma** instrução de texto | funda o texto novo na instrução que já existe, não crie outra |
| 176 dos 200 contatos com o mesmo motivo | a ordem do `CASE WHEN` | vá do sinal mais **raro** para o mais comum, senão o mais comum come todos |
| `CREATE FUNCTION` falha com coluna ambígua | parâmetro com o mesmo nome de uma coluna | prefixe com `p_` — está no prompt, mas acontece |
| `CREATE FUNCTION ... RETURNS TABLE` recusado | função de tabela indisponível no workspace | plano B: crie as quatro como **views** (`gold.ferramenta_*`) e mostre o Genie consultando; o argumento da aula é o mesmo |
| A fila veio com ~172 linhas | o descarte de vendedor desligado rodou DEPOIS do `LIMIT 200` | é o erro previsto no prompt: peça para filtrar antes de limitar. **Mostre a sujeira nº 9 da noite 2 cobrando o preço dela** |
| `motivo` com `NULL` no meio | faltou o `ELSE` no `CASE WHEN` | o teste 2 pegou. É o teste funcionando |
| O Genie inventou um número | a instrução não entrou no espaço | mostre o antes e o depois da instrução — vale mais que dez slides sobre alucinação |