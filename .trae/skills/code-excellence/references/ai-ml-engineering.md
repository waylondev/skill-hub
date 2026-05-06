# AI / ML Engineering — Architect-Level Reference

## Purpose

This reference encodes **production-grade ML engineering practices** that guide AI to build, deploy, monitor, and govern machine learning systems at scale. It spans model serving, feature stores, experimentation, MLOps, monitoring, LLM engineering, GPU optimization, data pipelines, anti-patterns, and responsible AI.

When you are designing an ML system, consult this file.

---

## 1. Model Serving Patterns

### 1.1 REST API with FastAPI

**Use when**: Synchronous inference, human-in-the-loop, or client-facing predictions with moderate latency requirements (p99 < 500ms).

```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import joblib
import numpy as np

app = FastAPI(title="Fraud Detection API", version="1.0.0")

# Load model at startup — never per-request
model = joblib.load("models/fraud_v3.joblib")

class PredictRequest(BaseModel):
    amount: float = Field(gt=0)
    merchant_id: int
    card_entry_mode: str
    hour_of_day: int = Field(ge=0, le=23)

class PredictResponse(BaseModel):
    fraud_probability: float
    model_version: str
    threshold: float

@app.post("/predict", response_model=PredictResponse)
def predict(req: PredictRequest):
    features = np.array([[req.amount, req.merchant_id, req.hour_of_day]])
    prob = model.predict_proba(features)[0][1]
    return PredictResponse(
        fraud_probability=round(prob, 4),
        model_version="fraud_v3",
        threshold=0.75
    )
```

**Expert rules**:
- Load model once at module level or in `lifespan` context — never inside the endpoint.
- Return model version with every prediction for traceability.
- Use Pydantic for strict input validation; reject garbage before it hits the model.
- Run under `uvicorn` with `--workers $(nproc)` for CPU-bound models.

### 1.2 gRPC for Low-Latency Serving

**Use when**: Internal microservice communication, sub-100ms p99 latency, high throughput.

```protobuf
syntax = "proto3";

service FraudPredictor {
  rpc Predict (PredictRequest) returns (PredictResponse);
  rpc PredictBatch (BatchRequest) returns (BatchResponse);
}

message PredictRequest {
  double amount = 1;
  int32 merchant_id = 2;
  int32 hour_of_day = 3;
}

message PredictResponse {
  double fraud_probability = 1;
  string model_version = 2;
}
```

```python
import grpc
from concurrent import futures
import fraud_pb2, fraud_pb2_grpc

class FraudServicer(fraud_pb2_grpc.FraudPredictorServicer):
    def __init__(self, model):
        self.model = model
        self.version = "fraud_v3"

    def Predict(self, request, context):
        features = [[request.amount, request.merchant_id, request.hour_of_day]]
        prob = self.model.predict_proba(features)[0][1]
        return fraud_pb2.PredictResponse(
            fraud_probability=prob, model_version=self.version
        )

server = grpc.server(futures.ThreadPoolExecutor(max_workers=10))
fraud_pb2_grpc.add_FraudPredictorServicer_to_server(FraudServicer(model), server)
server.add_insecure_port("[::]:50051")
server.start()
```

**Expert rules**:
- gRPC reduces serialization overhead by ~10x vs JSON for numeric payloads.
- Use `PredictBatch` for micro-batching to amortize per-request overhead.
- Always set `max_workers` based on model latency and desired concurrency.

### 1.3 Batch Inference with Spark

**Use when**: Nightly scoring of millions of records, feature pre-materialization, or backfills.

```python
from pyspark.sql import SparkSession
from pyspark.sql.functions import pandas_udf, col
from pyspark.sql.types import DoubleType
import pandas as pd
import joblib

spark = SparkSession.builder.appName("BatchScoring").getOrCreate()
model = joblib.load("models/fraud_v3.joblib")

@pandas_udf(DoubleType())
def score_batch(amount: pd.Series, merchant_id: pd.Series, hour: pd.Series) -> pd.Series:
    df = pd.DataFrame({"amount": amount, "merchant_id": merchant_id, "hour_of_day": hour})
    return pd.Series(model.predict_proba(df)[:, 1])

df = spark.read.parquet("s3://features/transactions/")
scored = df.withColumn("fraud_probability", score_batch(col("amount"), col("merchant_id"), col("hour_of_day")))
scored.write.mode("overwrite").parquet("s3://predictions/fraud/2026-05-06/")
```

**Expert rules**:
- Use `pandas_udf` for vectorized inference inside Spark executors.
- Coalesce to partition count matching executor cores to avoid stragglers.
- Write predictions with `model_version` and `scored_at` columns for lineage.

### 1.4 Model Versioning

```python
from datetime import datetime
from pathlib import Path
import hashlib

MODEL_REGISTRY = Path("/mnt/ml-registry")

def register_model(artifact_path: Path, metrics: dict) -> str:
    version = datetime.utcnow().strftime("%Y%m%d-%H%M%S")
    target = MODEL_REGISTRY / version
    target.mkdir(parents=True)
    artifact_path.rename(target / "model.joblib")

    # Content-addressable fingerprint
    fingerprint = hashlib.sha256((target / "model.joblib").read_bytes()).hexdigest()[:16]
    (target / "meta.json").write_text(json.dumps({
        "version": version,
        "fingerprint": fingerprint,
        "metrics": metrics,
        "registered_at": datetime.utcnow().isoformat()
    }))
    return version
```

**Expert rules**:
- Every production model MUST have a version string returned with predictions.
- Store model artifacts in immutable object storage (S3, GCS, MinIO) — never local disk in production.
- Use content-addressable storage (SHA-256) to guarantee artifact integrity.

---

## 2. Feature Store Architecture

### 2.1 Online vs Offline Stores

| Store | Latency | Consistency | Use Case | Technology |
|-------|---------|-------------|----------|------------|
| **Offline** | Minutes to hours | Eventual | Training, batch scoring, backfills | Delta Lake, BigQuery, Snowflake |
| **Online** | Milliseconds | Strong | Real-time inference, edge serving | Redis, DynamoDB, Feast Online Store |

```python
from feast import FeatureStore, Entity, Feature, FeatureView, ValueType
from feast.types import Float, Int64
from datetime import timedelta

store = FeatureStore(repo_path=".")

# Online retrieval for real-time inference
features = store.get_online_features(
    features=["user_stats:avg_transaction_7d", "user_stats:transaction_count_30d"],
    entity_rows=[{"user_id": "U12345"}]
).to_dict()

# Offline retrieval for training
job = store.get_historical_features(
    features=["user_stats:avg_transaction_7d"],
    entity_df=training_users
)
df = job.to_df()
```

### 2.2 Feature Registration & Consistency

```python
user = Entity(name="user_id", value_type=ValueType.STRING, description="User identifier")

user_stats_fv = FeatureView(
    name="user_stats",
    entities=["user_id"],
    ttl=timedelta(days=1),
    features=[
        Feature(name="avg_transaction_7d", dtype=Float),
        Feature(name="transaction_count_30d", dtype=Int64),
    ],
    online=True,
    source=user_transactions_source,
)
```

**Expert rules**:
- The SAME feature definition MUST serve both training and inference. Any divergence = training-serving skew.
- Use point-in-time correct joins for training data — no future leakage.
- TTL controls online staleness; set based on business tolerance (fraud: minutes, recommendations: hours).
- Materialize features to online store as part of the training pipeline, not ad-hoc.

---

## 3. A/B Testing Engineering Framework

### 3.1 Traffic Splitting

```python
import hashlib
from dataclasses import dataclass
from typing import Literal

@dataclass(frozen=True)
class ExperimentConfig:
    name: str
    control_ratio: float = 0.5
    treatment_ratio: float = 0.5
    salt: str = "2026-Q2"

def assign_variant(user_id: str, config: ExperimentConfig) -> Literal["control", "treatment"]:
    hash_val = int(hashlib.md5(f"{user_id}:{config.name}:{config.salt}".encode()).hexdigest(), 16)
    bucket = hash_val % 100 / 100.0
    return "treatment" if bucket >= config.control_ratio else "control"
```

**Expert rules**:
- Use deterministic hashing (user_id + experiment_name + salt) so assignments are sticky across sessions.
- Salt prevents correlation across experiments running simultaneously.
- Never use random assignment per-request — the same user must see the same variant.

### 3.2 Experiment Tracking with MLflow

```python
import mlflow
from mlflow.tracking import MlflowClient

mlflow.set_experiment("fraud-model-v3-ab")

with mlflow.start_run(run_name="treatment-xgboost"):
    mlflow.log_param("model_type", "xgboost")
    mlflow.log_param("max_depth", 8)
    mlflow.log_metric("auc_roc", 0.943)
    mlflow.log_metric("precision_at_90_recall", 0.812)
    mlflow.sklearn.log_model(model, "model", registered_model_name="fraud-detection")
```

### 3.3 Statistical Significance & Guardrail Metrics

```python
from scipy import stats
import numpy as np

def analyze_experiment(control: np.ndarray, treatment: np.ndarray) -> dict:
    # Primary metric: conversion rate (binomial)
    ctrl_rate = control.mean()
    treat_rate = treatment.mean()
    lift = (treat_rate - ctrl_rate) / ctrl_rate

    # Two-proportion z-test
    n1, n2 = len(control), len(treatment)
    p_pooled = (control.sum() + treatment.sum()) / (n1 + n2)
    se = np.sqrt(p_pooled * (1 - p_pooled) * (1/n1 + 1/n2))
    z = (treat_rate - ctrl_rate) / se
    p_value = 2 * (1 - stats.norm.cdf(abs(z)))

    return {
        "control_rate": ctrl_rate,
        "treatment_rate": treat_rate,
        "relative_lift": lift,
        "p_value": p_value,
        "significant": p_value < 0.05,
        "sample_size_control": n1,
        "sample_size_treatment": n2,
    }

# Guardrail metrics — MUST NOT degrade
# - Latency p99
# - Error rate
# - Revenue per user
# - Model fairness metrics (demographic parity)
```

**Expert rules**:
- Pre-register hypotheses before running experiments. No peeking.
- Run until pre-calculated sample size is reached, not until p < 0.05.
- Guardrail metrics act as automatic kill switches — if latency p99 degrades > 10%, stop the experiment immediately.

---

## 4. MLOps Pipeline

### 4.1 Training → Validation → Deployment → Monitoring

```yaml
# .github/workflows/ml-pipeline.yml
name: MLOps Pipeline

on:
  push:
    paths:
      - "training/**"
      - "features/**"

jobs:
  train:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Train Model
        run: python training/train.py --config training/config.yaml
      - name: Validate Metrics
        run: |
          python -c "
          import json
          with open('metrics.json') as f: m = json.load(f)
          assert m['auc_roc'] > 0.90, f'AUC too low: {m[\"auc_roc\"]}'
          assert m['precision_at_90_recall'] > 0.75
          "
      - name: Register Model
        if: github.ref == 'refs/heads/main'
        run: python training/register.py --model-path model.joblib

  deploy:
    needs: train
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to Staging
        run: kubectl apply -f k8s/staging/
      - name: Smoke Tests
        run: pytest tests/smoke/
      - name: Promote to Production
        run: kubectl apply -f k8s/production/
```

### 4.2 Model Registry

```python
from mlflow.tracking import MlflowClient

client = MlflowClient()

# Stage transitions
client.transition_model_version_stage(
    name="fraud-detection",
    version=3,
    stage="Staging"
)

# Promotion gate: require human approval + automated checks
client.transition_model_version_stage(
    name="fraud-detection",
    version=3,
    stage="Production",
    archive_existing_versions=True
)
```

**Expert rules**:
- Every model in production MUST be registered with version, metrics, training data fingerprint, and feature schema.
- Use canary deployments: 5% → 25% → 100% traffic shift with automated rollback on error rate or latency degradation.
- Separate training environment from serving environment — never train in production.

---

## 5. Model Monitoring

### 5.1 Data Drift

```python
from scipy.stats import ks_2samp, chi2_contingency
import pandas as pd

def detect_drift(reference: pd.Series, production: pd.Series, feature_type: str) -> dict:
    if feature_type == "numerical":
        statistic, p_value = ks_2samp(reference.dropna(), production.dropna())
        drifted = p_value < 0.01
    else:
        # Categorical: chi-square test
        ref_counts = reference.value_counts()
        prod_counts = production.value_counts().reindex(ref_counts.index, fill_value=0)
        _, p_value, _, _ = chi2_contingency([ref_counts, prod_counts])
        drifted = p_value < 0.01

    return {
        "feature": reference.name,
        "drift_detected": drifted,
        "p_value": p_value,
        "reference_mean": reference.mean() if feature_type == "numerical" else None,
        "production_mean": production.mean() if feature_type == "numerical" else None,
    }
```

### 5.2 Concept Drift

```python
def detect_concept_drift(
    recent_labels: pd.Series,
    recent_preds: pd.Series,
    baseline_auc: float,
    threshold: float = 0.05
) -> dict:
    from sklearn.metrics import roc_auc_score
    current_auc = roc_auc_score(recent_labels, recent_preds)
    return {
        "baseline_auc": baseline_auc,
        "current_auc": current_auc,
        "degradation": baseline_auc - current_auc,
        "drift_detected": (baseline_auc - current_auc) > threshold,
    }
```

### 5.3 Prediction Distribution Tracking

```python
def track_prediction_distribution(predictions: pd.Series) -> dict:
    return {
        "mean": predictions.mean(),
        "std": predictions.std(),
        "median": predictions.median(),
        "p05": predictions.quantile(0.05),
        "p95": predictions.quantile(0.95),
        "entropy": -((predictions * np.log(predictions + 1e-10)).sum()),
    }
```

**Expert rules**:
- Monitor input drift (features), output drift (predictions), and concept drift (ground truth vs predictions).
- Set up automated alerts: PagerDuty/Slack when drift p-value < 0.01 or AUC drops > 0.05.
- Log every prediction with input features, model version, timestamp, and prediction — this is your audit trail.
- Retrain trigger: drift detected + labeled data available + business impact confirmed.

---

## 6. LLM Engineering Patterns

### 6.1 Prompt Engineering Best Practices

```python
from dataclasses import dataclass

@dataclass(frozen=True)
class PromptTemplate:
    system: str
    user_template: str
    temperature: float = 0.1
    max_tokens: int = 512

    def render(self, **kwargs) -> list[dict]:
        return [
            {"role": "system", "content": self.system},
            {"role": "user", "content": self.user_template.format(**kwargs)},
        ]

# Structured output with JSON schema enforcement
CLASSIFICATION_PROMPT = PromptTemplate(
    system="You are a support ticket classifier. Respond ONLY with valid JSON.",
    user_template="""
Ticket: {ticket_text}

Classify into one of: [billing, technical, account, other].
Respond in this exact JSON format:
{{"category": "...", "confidence": 0.0-1.0, "reasoning": "..."}}
""",
    temperature=0.0,
)
```

**Expert rules**:
- Temperature = 0.0 for deterministic tasks (classification, extraction). Temperature > 0.7 for creative tasks.
- Always specify output format in the prompt; use structured output (JSON mode / function calling) when available.
- Version control prompts like code. A prompt change is a code change.
- Use system prompts for behavior, user prompts for context. Keep system prompts stable.

### 6.2 RAG Architecture

```python
from langchain.vectorstores import Chroma
from langchain.embeddings import OpenAIEmbeddings
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.schema import Document

# 1. Ingest and chunk documents
text_splitter = RecursiveCharacterTextSplitter(
    chunk_size=512,
    chunk_overlap=64,
    separators=["\n\n", "\n", ". ", " ", ""]
)
docs = [Document(page_content=c) for c in text_splitter.split_text(raw_text)]

# 2. Embed and index
vectorstore = Chroma.from_documents(docs, OpenAIEmbeddings(), collection_name="kb_v1")

# 3. Retrieve + Generate
retriever = vectorstore.as_retriever(search_kwargs={"k": 5})
context_docs = retriever.get_relevant_documents(query)
context = "\n\n".join([d.page_content for d in context_docs])

response = llm.chat([
    {"role": "system", "content": "Answer using ONLY the provided context."},
    {"role": "user", "content": f"Context:\n{context}\n\nQuestion: {query}"}
])
```

**Expert rules**:
- Chunk size must match embedding model's context window (OpenAI text-embedding-3: 8191 tokens).
- Overlap prevents semantic breaks at chunk boundaries.
- Re-rank retrieved chunks with a cross-encoder before sending to LLM — improves relevance by 15-30%.
- Maintain document provenance: every generated answer must cite source document IDs.

### 6.3 Token Management & Caching

```python
import tiktoken
from functools import lru_cache

enc = tiktoken.encoding_for_model("gpt-4")

def count_tokens(text: str) -> int:
    return len(enc.encode(text))

# Prompt caching: identical prompts should not be re-embedded
@lru_cache(maxsize=10_000)
def embed_query(text: str) -> tuple:
    return embedding_model.embed_query(text)

# Semantic cache: cache LLM responses for semantically similar queries
from sentence_transformers import SentenceTransformer
import numpy as np

class SemanticCache:
    def __init__(self, model_name: str = "all-MiniLM-L6-v2", threshold: float = 0.92):
        self.model = SentenceTransformer(model_name)
        self.cache: dict[str, str] = {}
        self.embeddings: list[np.ndarray] = []
        self.keys: list[str] = []
        self.threshold = threshold

    def get(self, query: str) -> str | None:
        if not self.keys:
            return None
        emb = self.model.encode(query)
        similarities = np.dot(self.embeddings, emb)
        best_idx = int(np.argmax(similarities))
        if similarities[best_idx] > self.threshold:
            return self.cache[self.keys[best_idx]]
        return None

    def set(self, query: str, response: str):
        self.cache[query] = response
        self.keys.append(query)
        self.embeddings.append(self.model.encode(query))
```

**Expert rules**:
- Track token usage per request; set budget alerts at 80% of monthly limit.
- Use `max_tokens` to cap response length and control cost.
- Semantic caching reduces LLM costs by 30-60% for FAQ and support use cases.
- Batch embedding requests when possible — 10x cheaper per token than single requests.

---

## 7. GPU Resource Management

### 7.1 Batching & Dynamic Batching

```python
import torch
from torch.utils.data import DataLoader

# Static batching during training
train_loader = DataLoader(dataset, batch_size=64, shuffle=True, num_workers=4, pin_memory=True)

# Dynamic batching for inference (Triton-style)
class DynamicBatcher:
    def __init__(self, model, max_batch_size: int = 32, max_wait_ms: float = 5.0):
        self.model = model
        self.max_batch_size = max_batch_size
        self.max_wait_ms = max_wait_ms
        self.queue = []

    def infer(self, request):
        self.queue.append(request)
        if len(self.queue) >= self.max_batch_size:
            return self._flush()
        # In production: timer-based flush after max_wait_ms

    def _flush(self):
        batch = torch.stack([r["input"] for r in self.queue])
        with torch.no_grad():
            results = self.model(batch)
        self.queue.clear()
        return results
```

### 7.2 Model Quantization

```python
from transformers import AutoModelForCausalLM, BitsAndBytesConfig

bnb_config = BitsAndBytesConfig(
    load_in_4bit=True,
    bnb_4bit_quant_type="nf4",
    bnb_4bit_compute_dtype=torch.bfloat16,
    bnb_4bit_use_double_quant=True,
)

model = AutoModelForCausalLM.from_pretrained(
    "meta-llama/Llama-2-7b",
    quantization_config=bnb_config,
    device_map="auto",
)
```

### 7.3 Inference Optimization

```python
# TorchScript / ONNX export for production serving
import torch.onnx

dummy_input = torch.randn(1, 3, 224, 224)
torch.onnx.export(
    model,
    dummy_input,
    "model.onnx",
    input_names=["input"],
    output_names=["output"],
    dynamic_axes={"input": {0: "batch_size"}, "output": {0: "batch_size"}},
)

# TensorRT for NVIDIA GPUs
import tensorrt as trt
# Use trtexec or ONNX-TensorRT for FP16/INT8 optimization
```

**Expert rules**:
- Dynamic batching improves GPU utilization from 30% to 80%+ for variable traffic.
- 4-bit quantization (QLoRA-style) reduces VRAM by 4x with < 1% accuracy loss for most LLMs.
- Use `torch.no_grad()` and `model.eval()` for inference — disables gradient computation and dropout.
- Profile with NVIDIA Nsight Systems before optimizing; measure first, optimize second.

---

## 8. Data Pipeline for ML

### 8.1 Feature Engineering

```python
from sklearn.base import BaseEstimator, TransformerMixin
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler, OneHotEncoder
from sklearn.compose import ColumnTransformer

class InteractionFeatures(BaseEstimator, TransformerMixin):
    def __init__(self, interaction_pairs: list[tuple[str, str]]):
        self.interaction_pairs = interaction_pairs

    def fit(self, X, y=None):
        return self

    def transform(self, X: pd.DataFrame) -> pd.DataFrame:
        X = X.copy()
        for a, b in self.interaction_pairs:
            X[f"{a}_x_{b}"] = X[a] * X[b]
        return X

preprocessor = ColumnTransformer([
    ("num", StandardScaler(), ["amount", "hour_of_day"]),
    ("cat", OneHotEncoder(handle_unknown="ignore"), ["merchant_category"]),
])

pipeline = Pipeline([
    ("interactions", InteractionFeatures([("amount", "hour_of_day")])),
    ("preprocess", preprocessor),
    ("model", XGBClassifier(max_depth=6)),
])
```

### 8.2 Training Data Versioning

```python
import dvc.api

# Track dataset with DVC
dvc.api.get_url(path="data/training.parquet", repo=".", remote="s3")

# Every training run references a specific data version
def load_training_data(version: str) -> pd.DataFrame:
    return pd.read_parquet(dvc.api.read(path="data/training.parquet", rev=version))
```

### 8.3 Synthetic Data Generation

```python
from sdv.single_table import CTGANSynthesizer
from sdv.metadata import SingleTableMetadata

metadata = SingleTableMetadata()
metadata.detect_from_dataframe(real_data)

synthesizer = CTGANSynthesizer(metadata, epochs=300)
synthesizer.fit(real_data)

synthetic_data = synthesizer.sample(num_rows=100_000)
```

**Expert rules**:
- Feature engineering MUST be part of the training pipeline, not a manual notebook step.
- Version training data with DVC or lakeFS; never use "latest" in production pipelines.
- Synthetic data is useful for augmentation and privacy, but validate statistical fidelity with KS tests and correlation matrices.
- Store feature transformation artifacts (scaler, encoder) alongside the model — serving requires identical transformations.

---

## 9. Common ML Engineering Anti-Patterns

### AP-ML-1: Training-Serving Skew

**Symptom**: Model performs well offline but degrades in production.

**Root Cause**: Features computed differently in training vs serving pipelines.

**Fix**:
- Use the SAME feature transformation code in both paths.
- Use a Feature Store to guarantee consistency.
- Log serving-time features and compare distributions to training data.

### AP-ML-2: Data Leakage

**Symptom**: Unrealistically high validation metrics that collapse in production.

**Root Cause**: Future information leaks into training (target encoding with global mean, time-series shuffle, leakage through ID).

**Fix**:
- Strict temporal split: train on [t0, t1], validate on [t1, t2], test on [t2, t3].
- Never shuffle time-series data.
- Compute target encodings ONLY within the training fold.

### AP-ML-3: No Model Versioning

**Symptom**: Cannot reproduce a prediction or rollback to a previous model.

**Fix**:
- Every model artifact MUST have a version, fingerprint, and associated metadata.
- Use MLflow, Weights & Biases, or a custom registry.

### AP-ML-4: No Monitoring

**Symptom**: Model silently degrades for weeks before discovery.

**Fix**:
- Monitor data drift, concept drift, and prediction distributions from day one.
- Set up automated alerts with escalation paths.

### AP-ML-5: Leaking PII in Training Data

**Symptom**: Model memorizes sensitive customer information.

**Fix**:
- Anonymize / tokenize PII before it enters the training pipeline.
- Use differential privacy for sensitive datasets.
- Audit training data for PII with tools like Presidio or AWS Macie.

---

## 10. Responsible AI

### 10.1 Bias Detection

```python
from fairlearn.metrics import demographic_parity_difference, equalized_odds_difference
from sklearn.metrics import accuracy_score

y_true = test_df["label"]
y_pred = model.predict(test_df[features])
sensitive = test_df["gender"]

dp_diff = demographic_parity_difference(y_true, y_pred, sensitive_features=sensitive)
eo_diff = equalized_odds_difference(y_true, y_pred, sensitive_features=sensitive)

print(f"Demographic Parity Difference: {dp_diff:.4f}")
print(f"Equalized Odds Difference: {eo_diff:.4f}")
```

### 10.2 Explainability

```python
import shap

explainer = shap.TreeExplainer(model)
shap_values = explainer.shap_values(X_test)

# Global explanation
shap.summary_plot(shap_values, X_test)

# Local explanation for a single prediction
shap.waterfall_plot(shap.Explanation(
    values=shap_values[0],
    base_values=explainer.expected_value,
    data=X_test.iloc[0],
    feature_names=X_test.columns
))
```

### 10.3 Fairness Metrics

| Metric | Definition | When to Use |
|--------|-----------|-------------|
| **Demographic Parity** | P(Ŷ=1 \| A=0) = P(Ŷ=1 \| A=1) | When outcome rates must be equal across groups |
| **Equalized Odds** | P(Ŷ=1 \| Y=y, A=0) = P(Ŷ=1 \| Y=y, A=1) | When true positive and false positive rates must match |
| **Calibration** | P(Y=1 \| Ŷ=p, A=0) = P(Y=1 \| Ŷ=p, A=1) | When predicted probabilities must be equally reliable |

### 10.4 Model Cards

```markdown
# Model Card: Fraud Detection v3.0

## Model Details
- **Architecture**: XGBoost (max_depth=8, n_estimators=500)
- **Training Date**: 2026-04-15
- **Dataset**: 10M transactions (2025-01 to 2026-03)

## Intended Use
- Real-time fraud scoring for e-commerce transactions
- NOT for credit scoring or insurance underwriting

## Factors
- Evaluated on: transaction amount, merchant category, time of day, user history
- Demographic factors: NOT used as features (gender, age, zip code excluded)

## Metrics
- AUC-ROC: 0.943
- Precision@90%Recall: 0.812
- False Positive Rate: 0.023

## Ethical Considerations
- Bias tested across merchant categories; no significant disparity detected.
- Explainability: SHAP values provided for every prediction.
- Human review required for scores in [0.6, 0.8] range.

## Caveats
- Performance degrades for merchants with < 100 historical transactions.
- Does not detect first-party fraud (stolen card used by cardholder).
```

**Expert rules**:
- Every production model MUST have a model card.
- Bias testing is not optional — test across all legally protected attributes and business-critical segments.
- Explainability is a requirement, not a nice-to-have, for high-stakes decisions (credit, hiring, healthcare).
- Establish a human-in-the-loop process for predictions in uncertain ranges.

---

## Quick Checklist

Before deploying an ML system:

- [ ] Model serving pattern chosen (REST / gRPC / batch) and latency requirements documented?
- [ ] Feature Store used with identical definitions for training and serving?
- [ ] A/B test framework configured with sticky assignment and guardrail metrics?
- [ ] MLOps pipeline automated: train → validate → register → deploy → monitor?
- [ ] Model registry tracks version, fingerprint, metrics, and feature schema?
- [ ] Monitoring covers data drift, concept drift, and prediction distribution?
- [ ] LLM prompts version-controlled with structured output and token budgets?
- [ ] RAG pipeline includes re-ranking and source provenance?
- [ ] GPU inference uses dynamic batching and quantization where applicable?
- [ ] Training data versioned with DVC or equivalent?
- [ ] Feature engineering encapsulated in reproducible pipelines?
- [ ] Training-serving skew eliminated through shared transformation code?
- [ ] Data leakage prevented with temporal splits and fold-aware encodings?
- [ ] Bias tested across all sensitive attributes with documented fairness metrics?
- [ ] SHAP or equivalent explainability available for every prediction?
- [ ] Model card written and reviewed before production release?
- [ ] Human-in-the-loop process defined for uncertain or high-stakes predictions?
