# · Rota do Perfume

Construir a área de dados e vendas de uma distribuidora B2B **do zero, em 4 noites**.
Empresa fictícia, dado gerado com seed fixa, sujeira proposital.

> **Domínio:** distribuidora de perfumaria árabe — vende para perfumarias, farmácias,
> revendedoras e e-commerces.
> **Stack:** Databricks Free Edition (serverless), SQL, Python e Claude Code.

---

## 🗓️ As noites

| Noite | Data | Tema | Pasta |
|---|---|---|---|
| **1** | seg 24/08 | Objetivo e a primeira análise | [`aulas/aula-01-databricks-sql`](aulas/aula-01-databricks-sql) · [📺 gravação](https://youtube.com/live/plG6mF-ib_w) |
| **2** | ter 25/08 | Engenharia de dados: o projeto roda sozinho | [`aulas/aula-02-engenharia-de-dados`](aulas/aula-02-engenharia-de-dados) · [📺 gravação](https://www.youtube.com/watch?v=0KRcn4ZIDPg) |
| **3** | qua 26/08 | Ciência de dados: o dado vira decisão | [`aulas/aula-03-ciencia-de-dados`](aulas/aula-03-ciencia-de-dados) · [📺 gravação](https://youtube.com/live/xAYkMee5OpA) |
| **4** | qui 27/08 | Apps e agentes: o projeto ganha uma URL | [`aulas/aula-04-app-e-genie`](aulas/aula-04-app-e-genie) · [📺 gravação](https://youtube.com/live/EnBiOrp-0_Q) |

Cada pasta é autocontida: tem o próprio README, os exemplos numerados e o que
for preciso rodar.

### O arco das quatro noites

```
  noite 1           noite 2            noite 3            noite 4
  ───────           ───────            ───────            ───────
  a query        →  vira camada     →  vira decisão   →   vira produto
  quebra no         que roda           modelo e fila      app, Genie e o
  dado sujo         sozinha            dos 200            retorno da ligação

  "qual foi        "como não          "para quem eu      "e quem não
   a receita?"      repetir isso?"     ligo segunda?"     escreve SQL?"
```

---

## 🧾 Os 12 prompts, na ordem

O projeto inteiro — do CSV cru ao app que escreve de volta na gold — sai de
**doze prompts colados em sequência no Claude Code**. Cada um termina com um
deploy.

**➡️ [`PROMPTS.md`](PROMPTS.md) — a sequência completa, com o texto de cada
prompt pronto para copiar.**

| Prompts | Noite | O que existe no fim |
|---|---|---|
| 1 a 6 | [engenharia](aulas/aula-02-engenharia-de-dados) | catálogo, pipeline de 12 tarefas, dashboard e Genie |
| 7 a 9 | [ciência de dados](aulas/aula-03-ciencia-de-dados) | modelo no Unity Catalog e a fila dos 200 · 15 tarefas |
| 10 a 12 | [apps e agentes](aulas/aula-04-app-e-genie) | Genie da direção, o app e o retorno da ligação · 16 tarefas |

O texto dos prompts no `PROMPTS.md` é **extraído dos arquivos de cada noite**,
não copiado à mão — os dois nunca divergem. O que fica só nos arquivos de cada
noite é o resto: o que mostrar antes de colar, o que falar enquanto o Claude
Code trabalha, e a tabela "se der errado".

---

## 🚀 Comece por aqui

```bash
# 1. gerar o dataset (seed fixa: todo mundo gera exatamente o mesmo dado)
python3 material/gerar_dataset.py --saida ./dados --seed 42

# 2. autenticar no Databricks (cria o profile e salva a credencial)
databricks auth login

# 3. seguir a aula 01, que é toda pelo navegador
cd aulas/aula-01-databricks-sql && cat README.md
```

A **noite 2** é a que exige terminal. O passo a passo completo — versões
mínimas, o erro de credencial que quase todo mundo vê, `bundle init`, skills,
MCP e guard rails — está em
[`aulas/aula-02-engenharia-de-dados/README.md`](aulas/aula-02-engenharia-de-dados/README.md#-passo-a-passo--do-zero-até-o-primeiro-deploy).

O runner `scripts/run_sql.py` executa qualquer `.sql` deste repositório no
warehouse, uma statement por vez:

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/exemplo-01-primeiro-select.sql
```

---

## 🎬 O catálogo nasce na aula

Os exemplos apontam para o catálogo **`lakehouse_rotaperfume`**, que
**ainda não existe** — ele é criado ao vivo, no primeiro bloco da noite 1:

```bash
python3 scripts/run_sql.py aulas/aula-01-databricks-sql/00-setup-catalogo.sql
```

Isso é proposital. O aluno vê o catálogo nascer vazio, os schemas serem
criados e o dado entrar — em vez de receber tudo pronto.

Se você já tem um catálogo com outro nome, troque o prefixo nas queries.

## 🗄️ O dataset

Gerado por `material/gerar_dataset.py`, ~14 MB, período de setembro/2024 a agosto/2026.

```
dados/
├── erp/    produtos · pedidos · itens_pedido · pagamentos · estoque
└── crm/    clientes · vendedores · carteira · oportunidades · visitas
```

| Tabela | Linhas | O que tem |
|---|---|---|
| `pedidos` | 28.729 | cliente, vendedor, data, canal, status, valor |
| `itens_pedido` | 197.724 | SKU, quantidade, preço praticado, desconto |
| `pagamentos` | 27.772 | forma, parcelas, vencimento, status |
| `produtos` | 292 | categoria, marca, nota olfativa, custo, lançamento |
| `estoque` | 8.400 | snapshot semanal por SKU, com ruptura |
| `clientes` | 3.040 | CNPJ, razão social, segmento, cidade |
| `visitas` | 37.936 | data, resultado, duração |
| `oportunidades` | 5.979 | funil: origem, etapa, valor, motivo de perda |
| `carteira` | 3.637 | vínculo vendedor ↔ cliente, com vigência |
| `vendedores` | 42 | região, admissão, desligamento, meta |

**A sujeira é proposital.** CNPJ em três formatos, data em dois, cliente
duplicado, devolução como quantidade negativa, vendedor desligado com carteira
ativa. Limpar isso é o conteúdo da noite 2 — não conserte o gerador.

---
