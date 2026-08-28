# Databricks notebook source
# COMMAND ----------
# MAGIC %md
# MAGIC # 12-modelo.py — Treinamento, Registro no MLflow Unity Catalog e Score de Propensão
# MAGIC
# MAGIC 1. Comparação contra 3 baselines empíricos no holdout
# MAGIC 2. Treinamento de HistGradientBoostingClassifier (sem imputação artificial de nulos)
# MAGIC 3. Avaliação de AUC no holdout e Lift no Top 200 via 5-fold Out-Of-Fold
# MAGIC 4. Análise de Importância por Permutação
# MAGIC 5. Registro do modelo no Unity Catalog (`gold.propensao_compra`) com alias `@prod`
# MAGIC 6. Três asserts rigorosos de qualidade e prevenção de vazamento
# MAGIC 7. Escoragem dos ~3.000 clientes em `gold.score_propensao` com faixas NTILE(4)
# MAGIC 8. Persistência das tabelas analíticas `gold.modelo_metricas` e `gold.calibragem_holdout`

# COMMAND ----------
import sys
import numpy as np
import pandas as pd
from pyspark.sql import SparkSession
from sklearn.model_selection import train_test_split, StratifiedKFold
from sklearn.metrics import roc_auc_score
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.inspection import permutation_importance
import mlflow
import mlflow.sklearn
from mlflow.tracking import MlflowClient
from databricks.sdk import WorkspaceClient

spark = SparkSession.builder.getOrCreate()

try:
    catalog = dbutils.widgets.get("catalog")
except Exception:
    catalog = "lakehouse_rotaperfume"

print(f"Executando pipeline de modelagem no catálogo: {catalog}")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 1. Leitura de Dados e Holdout (25% Estratificado)

# COMMAND ----------
# Leitura dos dados de treino
df_treino_spark = spark.table(f"{catalog}.gold.features_treino")
df_treino = df_treino_spark.toPandas()

COLS_EXCLUIR = ["cliente_id", "_referencia", "comprou_em_7d"]
FEATURE_COLS = [c for c in df_treino.columns if c not in COLS_EXCLUIR]

X = df_treino[FEATURE_COLS]
y = df_treino["comprou_em_7d"].astype(float)

# Holdout de 25% com seed 42 e estratificação pelo alvo
X_train, X_holdout, y_train, y_holdout = train_test_split(
    X, y, test_size=0.25, random_state=42, stratify=y
)

print(f"Total de registros para treino/validação: {len(X)}")
print(f"Treino: {len(X_train)} | Holdout: {len(X_holdout)} | Taxa base global: {y.mean():.4f}")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 2. Baselines Empíricos no Holdout

# COMMAND ----------
# a) -recencia_dias ("ligue para quem comprou recentemente")
auc_recencia = roc_auc_score(y_holdout, -X_holdout["recencia_dias"])

# b) valor_total ("ligue para quem compra mais")
auc_valor = roc_auc_score(y_holdout, X_holdout["valor_total"])

# c) atraso_relativo ("ligue para quem está atrasado") - NaN tratado como 0 (sem ritmo prévio)
auc_atraso = roc_auc_score(y_holdout, X_holdout["atraso_relativo"].fillna(0))

melhor_baseline = max(auc_recencia, auc_valor, auc_atraso)

print("=" * 65)
print("BASELINES EMPÍRICOS (AVALIAÇÃO NO HOLDOUT)")
print("=" * 65)
print(f"Regra 1: 'Ligue para quem comprou recentemente' (-recência) : AUC = {auc_recencia:.4f}")
print(f"Regra 2: 'Moeda aleatória'                                : AUC = 0.5000")
print(f"Regra 3: 'Ligue para quem compra mais' (valor total)      : AUC = {auc_valor:.4f}")
print(f"Regra 4: 'Ligue para quem está atrasado' (atraso relativo) : AUC = {auc_atraso:.4f}")
print("=" * 65)
print(f"Melhor baseline empírico: AUC = {melhor_baseline:.4f}")
print("=" * 65)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 3. Treinamento do HistGradientBoostingClassifier

# COMMAND ----------
clf = HistGradientBoostingClassifier(random_state=42)
clf.fit(X_train, y_train)

# Predição no holdout
y_holdout_pred_proba = clf.predict_proba(X_holdout)[:, 1]
auc_holdout = roc_auc_score(y_holdout, y_holdout_pred_proba)

print(f"AUC do Modelo no Holdout: {auc_holdout:.4f}")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 4. Avaliação de Lift no Top 200 via Validação Cruzada Out-Of-Fold

# COMMAND ----------
skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
oof_preds = np.zeros(len(df_treino))

for fold, (train_idx, val_idx) in enumerate(skf.split(X, y)):
    m = HistGradientBoostingClassifier(random_state=42)
    m.fit(X.iloc[train_idx], y.iloc[train_idx])
    oof_preds[val_idx] = m.predict_proba(X.iloc[val_idx])[:, 1]

# Ordenar toda a base de treino pelo score decrescente
ordem_scores = np.argsort(-oof_preds)
top200_indices = ordem_scores[:200]
top200_y = y.iloc[top200_indices]

acertos_top200 = int(top200_y.sum())
taxa_top200 = acertos_top200 / 200.0
taxa_base = float(y.mean())
lift_top200 = taxa_top200 / taxa_base

print("=" * 65)
print("AVALIAÇÃO DE LIFT NO TOP 200 (OUT-OF-FOLD 5-FOLDS)")
print("=" * 65)
print(f"Taxa base aleatória da carteira : {taxa_base * 100:.2f}% (esperado ~20 acertos em 200)")
print(f"Acertos no Top 200 do modelo    : {acertos_top200} de 200 ({taxa_top200 * 100:.2f}%)")
print(f"Lift sobre a taxa base          : {lift_top200:.2f}x")
print("=" * 65)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 5. Importância das Features por Permutação

# COMMAND ----------
perm_result = permutation_importance(
    clf, X_holdout, y_holdout, n_repeats=5, random_state=42, scoring="roc_auc"
)

top_indices = np.argsort(-perm_result.importances_mean)
feature_top1 = FEATURE_COLS[top_indices[0]]

print("=" * 65)
print("TOP 10 FEATURES MAIS IMPORTANTES (PERMUTAÇÃO NO HOLDOUT)")
print("=" * 65)
for i in range(min(10, len(FEATURE_COLS))):
    idx = top_indices[i]
    feat = FEATURE_COLS[idx]
    mean_imp = perm_result.importances_mean[idx]
    std_imp = perm_result.importances_std[idx]
    print(f"{i+1:2d}. {feat:<25} : {mean_imp:.4f} ± {std_imp:.4f}")
print("=" * 65)
print(f"Feature nº 1: {feature_top1}")
print("=" * 65)

# COMMAND ----------
# MAGIC %md
# MAGIC ## 6. Três Asserts de Qualidade e Governança

# COMMAND ----------
# 1. O modelo ganha do melhor baseline por pelo menos 0,05 de AUC
assert auc_holdout >= (melhor_baseline + 0.05), (
    f"Modelo (AUC {auc_holdout:.4f}) não superou o melhor baseline ({melhor_baseline:.4f}) "
    f"por pelo menos 0.05 de AUC (diferença: {auc_holdout - melhor_baseline:.4f})."
)

# 2. AUC < 0.99 — bom demais é sinal de vazamento de dados (leakage)
assert auc_holdout < 0.99, (
    f"AUC ({auc_holdout:.4f}) excessivamente alto (>= 0.99) indica vazamento de dados."
)

# 3. Lift Top 200 >= 2.5 — viabilidade comercial do projeto
assert lift_top200 >= 2.5, (
    f"Lift no Top 200 ({lift_top200:.2f}x) abaixo do mínimo aceitável de 2.5x."
)

print("Todos os 3 asserts de governança e viabilidade passaram com sucesso!")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 7. Registro no MLflow Unity Catalog e Alias @prod

# COMMAND ----------
from mlflow.models.signature import infer_signature

# Configurar registro no Unity Catalog
mlflow.set_registry_uri("databricks-uc")

# Criar pasta do experimento no workspace
w = WorkspaceClient()
user_name = w.current_user.me().user_name
experiment_dir = f"/Users/{user_name}/rotaperfume_ml"
try:
    w.workspace.mkdirs(experiment_dir)
except Exception:
    pass

mlflow.set_experiment(f"{experiment_dir}/propensao_compra")

model_name = f"{catalog}.gold.propensao_compra"

# Assinatura de modelo obrigatória para registro no Unity Catalog
signature = infer_signature(X_train, clf.predict_proba(X_train)[:, 1])

with mlflow.start_run(run_name="hist_gradient_boosting_propensao") as run:
    mlflow.log_params({
        "model_type": "HistGradientBoostingClassifier",
        "random_state": 42,
        "test_size": 0.25,
        "n_folds_cv": 5,
        "top_n_lift": 200
    })
    
    mlflow.log_metrics({
        "auc": float(auc_holdout),
        "lift_top200": float(lift_top200),
        "acertos_top200": float(acertos_top200),
        "taxa_base": float(taxa_base),
        "auc_baseline_recencia": float(auc_recencia),
        "auc_baseline_valor": float(auc_valor),
        "auc_baseline_atraso": float(auc_atraso)
    })
    
    # MLflow 2.22: log_model com artifact_path="modelo", signature e registered_model_name
    mlflow.sklearn.log_model(
        sk_model=clf,
        artifact_path="modelo",
        registered_model_name=model_name,
        signature=signature
    )


# Apontar alias @prod no Unity Catalog
client = MlflowClient()
versions = client.search_model_versions(f"name = '{model_name}'")
latest_version = max([int(v.version) for v in versions])
client.set_registered_model_alias(name=model_name, alias="prod", version=str(latest_version))

print(f"Modelo {model_name} registrado na versão {latest_version} com alias @prod.")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 8. Escoragem de Clientes e Geração de gold.score_propensao

# COMMAND ----------
# Carregar modelo oficial em produção via alias @prod
modelo_prod = mlflow.sklearn.load_model(f"models:/{model_name}@prod")

# Carregar clientes de corte 2026-08-31
df_score_raw = spark.table(f"{catalog}.gold.features_cliente").toPandas()

# Garantir exatamente as mesmas features e mesma ordem do modelo
features_modelo = list(modelo_prod.feature_names_in_)
X_score = df_score_raw[features_modelo]

# Prever probabilidades com predict_proba
scores = modelo_prod.predict_proba(X_score)[:, 1]
df_score_raw["score"] = scores

# Criar temp view para aplicar NTILE(4) via Spark SQL
spark.createDataFrame(
    df_score_raw[["cliente_id", "_referencia", "score"]]
).createOrReplaceTempView("tmp_scores")

df_score_final = spark.sql(f"""
    SELECT
      CAST(cliente_id AS INT) AS cliente_id,
      CAST(score AS DOUBLE) AS score,
      CASE NTILE(4) OVER (ORDER BY score ASC)
        WHEN 1 THEN 'Fria'
        WHEN 2 THEN 'Morna'
        WHEN 3 THEN 'Quente'
        WHEN 4 THEN 'Muito quente'
      END AS faixa,
      _referencia,
      CAST({latest_version} AS INT) AS versao_modelo
    FROM tmp_scores
""")

df_score_final.write.format("delta").mode("overwrite").saveAsTable(f"{catalog}.gold.score_propensao")
spark.sql(f"COMMENT ON TABLE {catalog}.gold.score_propensao IS 'Pontuação de propensão semanal de compra dos clientes com faixas NTILE(4)'")

print(f"Tabela {catalog}.gold.score_propensao criada com {df_score_final.count()} clientes pontuados.")

# COMMAND ----------
# MAGIC %md
# MAGIC ## 9. Tabelas de Métricas e Calibragem para Governança

# COMMAND ----------
# Tabela 1: gold.modelo_metricas
spark.sql(f"""
    CREATE OR REPLACE TABLE {catalog}.gold.modelo_metricas AS
    SELECT
      CAST({latest_version} AS INT) AS versao,
      CAST({auc_holdout} AS DOUBLE) AS auc,
      CAST({lift_top200} AS DOUBLE) AS lift_top200,
      CAST({acertos_top200} AS INT) AS acertos_top200,
      CAST({taxa_base} AS DOUBLE) AS taxa_base,
      CAST({auc_recencia} AS DOUBLE) AS auc_baseline_recencia,
      CAST({auc_valor} AS DOUBLE) AS auc_baseline_valor,
      CAST({auc_atraso} AS DOUBLE) AS auc_baseline_atraso,
      '{feature_top1}' AS feature_top1,
      current_timestamp() AS _treinado_em
""")
spark.sql(f"COMMENT ON TABLE {catalog}.gold.modelo_metricas IS 'Métricas consolidadas de treinamento e baselines do modelo de propensão'")

# Tabela 2: gold.calibragem_holdout
df_holdout_eval = pd.DataFrame({
    "score": y_holdout_pred_proba,
    "comprou": y_holdout.values
})
spark.createDataFrame(df_holdout_eval).createOrReplaceTempView("tmp_holdout_eval")

spark.sql(f"""
    CREATE OR REPLACE TABLE {catalog}.gold.calibragem_holdout AS
    WITH ranked AS (
      SELECT
        score,
        comprou,
        CASE NTILE(4) OVER (ORDER BY score ASC)
          WHEN 1 THEN 'Fria'
          WHEN 2 THEN 'Morna'
          WHEN 3 THEN 'Quente'
          WHEN 4 THEN 'Muito quente'
        END AS faixa
      FROM tmp_holdout_eval
    )
    SELECT
      faixa,
      COUNT(*) AS clientes,
      CAST(SUM(comprou) AS INT) AS compraram,
      CAST(AVG(comprou) AS DOUBLE) AS taxa_de_compra,
      CAST(AVG(score) AS DOUBLE) AS score_medio
    FROM ranked
    GROUP BY faixa
""")
spark.sql(f"COMMENT ON TABLE {catalog}.gold.calibragem_holdout IS 'Calibragem de faixas de propensão e taxa real de conversão no conjunto holdout'")

print("Tabelas gold.modelo_metricas e gold.calibragem_holdout criadas com sucesso.")
