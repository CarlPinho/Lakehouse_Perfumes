#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Script: subir-raw.sh
# Objetivo: Upload dos CSVs de ERP e CRM para o Volume do Unity Catalog:
#           dbfs:/Volumes/lakehouse_rotaperfume/bronze/raw/erp
#           dbfs:/Volumes/lakehouse_rotaperfume/bronze/raw/crm
#
# IMPORTANTE:
# O comando databricks fs cp exige o esquema 'dbfs:' no destino, mesmo tratando-se
# de um Volume do Unity Catalog.
# ==============================================================================

PROFILE="${1:-}"
CATALOG="lakehouse_rotaperfume"

# Identificar a raiz do repositório
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DADOS_DIR="${REPO_ROOT}/dados"

# Se o diretório dados não existir ou estiver vazio, tenta gerar caso o gerador exista
if [ ! -d "${DADOS_DIR}/erp" ] || [ ! -d "${DADOS_DIR}/crm" ]; then
  if [ -f "${REPO_ROOT}/material/gerar_dataset.py" ]; then
    echo "==> Gerando dataset inicial via material/gerar_dataset.py..."
    python3 "${REPO_ROOT}/material/gerar_dataset.py" --saida "${DADOS_DIR}" --seed 42
  else
    echo "Aviso: Diretórios de dados ${DADOS_DIR}/erp ou ${DADOS_DIR}/crm não encontrados."
  fi
fi

if [ -n "${PROFILE}" ]; then
  echo "==> [1/2] Fazendo upload dos arquivos ERP para dbfs:/Volumes/${CATALOG}/bronze/raw/erp (profile: ${PROFILE})..."
  databricks fs cp --recursive --overwrite "${DADOS_DIR}/erp" "dbfs:/Volumes/${CATALOG}/bronze/raw/erp" --profile "${PROFILE}"

  echo "==> [2/2] Fazendo upload dos arquivos CRM para dbfs:/Volumes/${CATALOG}/bronze/raw/crm (profile: ${PROFILE})..."
  databricks fs cp --recursive --overwrite "${DADOS_DIR}/crm" "dbfs:/Volumes/${CATALOG}/bronze/raw/crm" --profile "${PROFILE}"
else
  echo "==> [1/2] Fazendo upload dos arquivos ERP para dbfs:/Volumes/${CATALOG}/bronze/raw/erp ..."
  databricks fs cp --recursive --overwrite "${DADOS_DIR}/erp" "dbfs:/Volumes/${CATALOG}/bronze/raw/erp"

  echo "==> [2/2] Fazendo upload dos arquivos CRM para dbfs:/Volumes/${CATALOG}/bronze/raw/crm ..."
  databricks fs cp --recursive --overwrite "${DADOS_DIR}/crm" "dbfs:/Volumes/${CATALOG}/bronze/raw/crm"
fi

echo " Upload dos 10 arquivos brutos para a camada Raw concluído com sucesso!"
