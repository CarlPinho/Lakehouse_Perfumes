# · Rota do Perfume

Construir a área de dados e vendas de uma distribuidora B2B **do zero, em 4 noites**.
Empresa fictícia, dado gerado com seed fixa, sujeira proposital.

> **Domínio:** distribuidora de perfumaria árabe — vende para perfumarias, farmácias,
> revendedoras e e-commerces.
> **Stack:** Databricks Free Edition (serverless), SQL, Python e Claude Code.

---
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
