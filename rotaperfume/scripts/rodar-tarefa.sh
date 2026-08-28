#!/usr/bin/env bash
# ==============================================================================
# rodar-tarefa.sh: Executa uma tarefa específica do bundle rotaperfume_pipeline
# Uso: bash scripts/rodar-tarefa.sh [perfil] <nome_tarefa>
# ==============================================================================
set -euo pipefail

PROFILE="${1:-}"
TASK="${2:-}"

if [[ -z "$TASK" ]]; then
  TASK="$PROFILE"
  PROFILE=""
fi

if [[ -z "$TASK" ]]; then
  echo "Uso: bash scripts/rodar-tarefa.sh [perfil] <nome_tarefa>"
  echo "Exemplo: bash scripts/rodar-tarefa.sh ml_features"
  exit 1
fi

CMD=(databricks bundle run rotaperfume_pipeline --only "$TASK" --target dev)
if [[ -n "$PROFILE" ]]; then
  CMD+=(--profile "$PROFILE")
fi

echo "Executando: ${CMD[*]}"
"${CMD[@]}"
