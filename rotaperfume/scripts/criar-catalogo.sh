#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: criar-catalogo.sh
# Objetivo: Criar o catálogo lakehouse_rotaperfume no Unity Catalog
#
# POR QUE NÃO ESTÁ NO BUNDLE:
# No Databricks Free Edition o Default Storage está ligado, e nessa configuração
# a API do Unity Catalog RECUSA criar catálogo — ela exige um MANAGED LOCATION
# que a conta gratuita não tem:
#   Error: Metastore storage root URL does not exist.
#          Default Storage is enabled in your account. (400 INVALID_STATE)
# O comando SQL funciona normalmente via SQL Warehouse / aitools.
# ==============================================================================

if [ -z "${1:-}" ]; then
  echo "Erro: Profile do Databricks CLI não informado."
  echo "Uso: $0 <profile>"
  exit 1
fi

PROFILE="$1"
CATALOG="lakehouse_rotaperfume"

echo "==> [1/1] Criando catálogo '${CATALOG}' via SQL (Profile: ${PROFILE})..."

SQL_STMT="CREATE CATALOG IF NOT EXISTS ${CATALOG} COMMENT 'Catálogo principal do Lakehouse Rota Perfume';"

# Execução via Databricks SQL Statements API
if command -v databricks &> /dev/null; then
  WAREHOUSE_ID=$(databricks warehouses list --profile "${PROFILE}" -o json 2>/dev/null | grep -o '"id": "[^"]*' | head -n 1 | cut -d'"' -f4 || echo "")
  if [ -n "${WAREHOUSE_ID}" ]; then
    echo "Executando via SQL Warehouse ${WAREHOUSE_ID}..."
    databricks api post /api/2.0/sql/statements --json "{\"warehouse_id\":\"${WAREHOUSE_ID}\",\"statement\":\"${SQL_STMT}\"}" --profile "${PROFILE}"
    echo " Catálogo '${CATALOG}' criado/verificado com sucesso!"
  else
    echo "Nenhum SQL Warehouse encontrado ativo."
  fi
else
  echo "Erro: CLI do Databricks ('databricks') não encontrada no PATH."
  exit 1
fi
