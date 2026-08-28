# Prompt 1 · O Genie da direção

**Slides que acompanham:** 19 a 24 (divisor *"A porta que já existia"*, um Genie
por audiência, o que é instrução de negócio, a tabela que nasce vazia).

**Entrega:** o space `Rota do Perfume · Direção` como código no bundle, mais
`gold.retorno_ligacao` e a tarefa que a cria. **Deploy nº 1 da noite.**

> O Genie da noite 2 tem doze fontes e serve para perguntar qualquer coisa. Este
> tem sete e serve para responder **uma decisão**. A diferença não é técnica —
> é de audiência, e é o argumento do prompt.

---

## O ambiente, conferido hoje

Rodado contra `lakehouse_rotaperfume` no workspace. **Tudo o que este prompt lê
já existe:**

| Fonte | O que este prompt faz com ela |
|---|---|
| `gold.fila_semanal` | 200 linhas, 35 vendedores — é o assunto principal do space |
| `gold.score_propensao` | a nota de todos os 2.816 clientes, não só dos 200 |
| `gold.modelo_metricas` | 3 versões; a última tem `lift_top200` = 4,25 |
| `gold.clientes_em_risco`, `ranking_marcas`, `receita_mensal` | as views da noite 2, para a pergunta que escapa da fila |

O que **não** existe ainda: `gold.retorno_ligacao` e o segundo Genie space.
Ambos nascem aqui.

O job está com **15 tarefas** e o `bundle deploy` passa limpo.

> **No deploy, se aparecer pedido de confirmação para APAGAR o dashboard ou o
> Genie comercial: recuse e me chame.** As chaves dos recursos que já existem
> (`dashboard_comercial`, `genie_comercial`) não podem ser renomeadas — trocar a
> chave faz o bundle apagar e recriar, com URL nova. **Nunca use
> `--auto-approve` aqui.**

---

## O que mostrar antes

**1 · O Genie que já existe, com a pergunta do diretor**

Abra o `Rota do Perfume · Comercial` da noite 2 e pergunte:

> *"Quem eu ligo essa semana?"*

Ele responde — a fila entrou nas fontes dele na noite 3. Guarde a resposta.

**2 · E agora a pergunta que expõe o problema**

> *"Quantas dessas ligações viraram pedido?"*

Ele **não tem como saber**. A informação não existe em lugar nenhum do projeto:
o pipeline sabe a quem ligar e nunca fica sabendo o que aconteceu depois.

```sql
-- procure a tabela que responderia. Ela não está aqui.
SHOW TABLES IN lakehouse_rotaperfume.gold;
```

> *"Três noites construindo o caminho de ida. Hoje a gente constrói o de volta —
> e ele começa com uma tabela vazia."*

**3 · A pergunta de desenho, para a sala**

> *"Eu já tenho um Genie. Por que eu criaria um segundo, com o mesmo dado
> embaixo?"*

A resposta que quase sempre aparece é "não criaria". E aí:

> *"O vendedor pergunta 'quanto o cliente X comprou no ano'. O diretor pergunta
> 'quanto vale a fila'. Se os dois moram no mesmo espaço, as instruções brigam:
> o que serve para um vira ruído para o outro. **Genie não é um por empresa. É
> um por audiência.**"*

---

**Enquanto ele trabalha, você explica:**

- **A instrução é o produto.** O modelo é o mesmo, o dado é o mesmo. O que faz
  este Genie responder melhor que o outro para o diretor são vinte linhas de
  texto escritas por alguém que entende o negócio — e elas moram no Git, com
  revisão e histórico.
- **"Nunca cite AUC" é uma regra de negócio.** Não é preciosismo: quem pergunta
  aqui decide ligação, não modelo. A métrica dele é `lift_top200`.
- **A tabela que nasce vazia.** `retorno_ligacao` é a única tabela do projeto
  cujo dado não vem do pipeline — vem do time. Por isso ela é a única com
  `CREATE TABLE IF NOT EXISTS`: um redeploy não pode apagar o que o vendedor
  respondeu.
- **Resposta vazia é resposta certa.** O Genie precisa ser instruído a dizer
  "ninguém registrou retorno ainda" em vez de inventar um número ou usar a fila
  como se fosse retorno.

---

## O prompt

```
Continue o bundle em aulas/aula-02-engenharia-de-dados/rotaperfume/.
A noite 3 deixou gold.fila_semanal com 200 contatos e gold.score_propensao
com a nota de todos os clientes. Hoje eu quero duas coisas: a tabela onde o
time registra o que aconteceu depois da ligação, e um Genie space feito para
a direção.

1. src/gold/11-retorno-ligacao.sql — a tabela do caminho de volta

   CREATE TABLE IF NOT EXISTS lakehouse_rotaperfume.gold.retorno_ligacao com:
     cliente_id      INT
     vendedor        STRING
     status          STRING     vendeu | vai_pensar | sem_interesse | nao_atendeu
     comentario      STRING     texto livre do vendedor
     registrado_em   TIMESTAMP
     registrado_por  STRING     e-mail de quem estava logado
     _referencia     DATE       a semana da fila

   IF NOT EXISTS, e não CREATE OR REPLACE: é a ÚNICA tabela do projeto cujo
   dado não vem do pipeline. Um redeploy não pode apagar o que o time
   respondeu.

   COMMENT em toda coluna e na tabela — a auditoria de metadado da noite 2
   quebra o job se faltar, e é o COMMENT que o Genie lê para escolher coluna.

   Acrescente ao pipeline a tarefa gold_retorno_ligacao, depois de gold_marts.
   O job vai de 15 para 16 tarefas.

2. resources/direcao.geniespace.json + resources/genie-direcao.genie_space.yml

   Um SEGUNDO Genie space, chamado "Rota do Perfume · Direção". Não altere o
   genie_comercial que já existe — a chave dele não pode mudar.

   Fontes, e só estas sete:
     gold.fila_semanal      o assunto principal
     gold.score_propensao   a nota de todos, para o cliente fora da fila
     gold.modelo_metricas   lift_top200, acertos_top200, taxa_base
     gold.retorno_ligacao   o que aconteceu depois
     gold.clientes_em_risco, gold.ranking_marcas, gold.receita_mensal

   As instruções, em português, cobrindo:
   - quem pergunta: a direção comercial, que não escreve SQL e decide ligação
   - o que é score (0 a 1, chance de comprar em 7 dias), faixa, ordem, motivo
   - por que a fila é GLOBAL e não cota por vendedor: quem tem carteira quente
     recebe mais contatos, e isso está certo
   - receita esperada da fila = SUM(score * ticket_medio), e é ESTIMATIVA,
     nunca receita realizada
   - a métrica da direção é lift_top200. NUNCA cite AUC para responder
     pergunta de negócio: AUC é métrica de quem treina
   - retorno_ligacao começa VAZIA. Se a resposta for zero, diga que ninguém
     registrou retorno ainda — não invente número, e não use a fila como se
     fosse retorno
   - um cliente pode ter mais de um retorno: para o estado atual, use o mais
     recente por registrado_em
   - a sazonalidade é INVERTIDA: o pico é o mês ANTERIOR à data comemorativa
   - nunca use o schema bronze

   5 sample_questions e 5 pares pergunta -> SQL já validado, incluindo
   "Quem eu ligo essa semana?", "Quanto vale a fila desta semana?" e
   "Quantas ligações já foram registradas e quantas viraram pedido?".

   AS QUATRO REGRAS DA API QUE FAZEM O DEPLOY FALHAR:
   a) data_sources.tables ORDENADO por identifier
   b) column_configs de cada tabela ordenado por column_name
   c) todo id com 32 caracteres hexadecimais minúsculos, sem hífen
   d) as listas de perguntas e instruções também ordenadas por id

   Gere os ids com md5 do conteúdo — determinístico. Um redeploy não pode
   recriar as perguntas nem sujar o diff do Git.

3. Rode, e me mostre o resultado:
   databricks bundle validate --target dev --profile projeto-dados-ia
   databricks bundle deploy   --target dev --profile projeto-dados-ia
   bash scripts/rodar-tarefa.sh projeto-dados-ia gold_retorno_ligacao

   NÃO use --auto-approve. Se o deploy pedir para apagar o dashboard ou o
   genie_comercial, pare e me avise.
```

---

## Como verificar a feature

**1 · A tabela existe, está vazia e tem metadado**

```sql
DESCRIBE TABLE EXTENDED lakehouse_rotaperfume.gold.retorno_ligacao;

-- tem que voltar 0. Vazia no começo da noite é o estado correto.
SELECT COUNT(*) AS linhas FROM lakehouse_rotaperfume.gold.retorno_ligacao;

-- tem que voltar VAZIO: nenhuma coluna sem COMMENT
SELECT column_name
FROM   lakehouse_rotaperfume.information_schema.columns
WHERE  table_schema = 'gold' AND table_name = 'retorno_ligacao'
  AND  (comment IS NULL OR comment = '');
```

**2 · O segundo space existe, e o primeiro continua de pé**

```bash
databricks genie list-spaces --profile projeto-dados-ia
# tem que listar DOIS spaces do projeto: · Comercial e · Direção
```

**3 · As três perguntas no Genie novo — e é aqui que a sala vê a diferença**

Abra o `Rota do Perfume · Direção` e pergunte, nesta ordem:

| Pergunta | O que tem que aparecer |
|---|---|
| *"Quanto vale a fila desta semana?"* | **R$ 582.799,50** e a palavra *estimativa* |
| *"Quantas ligações já foram registradas?"* | **zero** — e a frase de que ninguém registrou ainda |
| *"O modelo é bom?"* | **4,25×** ou *86 de 200*. **Não pode citar AUC** |

Confira o primeiro contra a query, na frente da sala:

```sql
SELECT ROUND(SUM(score * ticket_medio), 2) AS receita_esperada
FROM   lakehouse_rotaperfume.gold.fila_semanal;
-- 582799.50
```

> **Use o botão *Show generated code* em toda resposta.** É o hábito que separa
> quem usa Genie de quem confia em Genie. O número que vai para a reunião é o
> que você conferiu, não o que apareceu na tela.

**4 · O que quebra o job de propósito, se sobrar tempo**

```sql
-- tire o COMMENT de uma coluna e rode a auditoria: o job cai.
ALTER TABLE lakehouse_rotaperfume.gold.retorno_ligacao
  ALTER COLUMN comentario COMMENT '';
```

```bash
bash scripts/rodar-tarefa.sh projeto-dados-ia auditoria_de_metadado   # FAILED
```

Metadado faltando é bug, não pendência de documentação — e a regra da noite 2
continua valendo para a tabela que nasceu hoje.

---

## Se der errado

| Sintoma | Causa | Saída |
|---|---|---|
| `bundle deploy` pede para apagar o dashboard ou o Genie comercial | a chave de um recurso existente foi renomeada | Recuse. Volte a chave para `dashboard_comercial` / `genie_comercial` |
| Deploy falha com erro de ordenação | `tables`, `column_configs` ou as listas de id fora de ordem | Ordene: `identifier`, `column_name`, `id` |
| Deploy falha reclamando de `id` | id com hífen, maiúscula ou tamanho ≠ 32 | md5 do conteúdo, minúsculo, sem hífen |
| A tarefa `gold_retorno_ligacao` falha | `${catalog}` dentro de um `sql_task` | Nos `.sql` deste bundle o catálogo é **literal**: `lakehouse_rotaperfume` |
| O Genie novo não acha a fila | a tabela não entrou em `data_sources` | Confira as sete fontes no JSON |
| O Genie responde com AUC | a instrução não foi explícita | A regra tem que dizer *"NUNCA cite AUC"*, com a palavra nunca |
| O Genie inventa retorno | faltou a regra da tabela vazia | Acrescente: *"se for zero, diga que ninguém registrou ainda"* |