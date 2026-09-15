# Software Requirements Specification (SRS)

## Project: NanoAlign
**Author**: Nachiket Gadilohar ([nachiketlohar0306@gmail.com](mailto:nachiketlohar0306@gmail.com))  
**Repository**: [github.com/nachiket0987/NanoAlign](https://github.com/nachiket0987/NanoAlign)  
**Document Version**: 1.0.0  

---

## 1. System Overview & Scope

NanoAlign is a modular, high-performance software framework for post-training, preference optimization, reinforcement learning, and evaluation of Causal Language Models. The system executes as a CLI toolsuite, Python library, and containerized microservice.

---

## 2. User Roles & Access Control Matrix (RBAC)

```
+------------------+------------------+-------------------+--------------------+
| ROLE             | EXECUTE PIPELINE | READ METRICS/LOGS | MODIFY CHECKPOINTS |
+------------------+------------------+-------------------+--------------------+
| Admin / Lead     | FULL ALLOW       | FULL ALLOW        | FULL ALLOW         |
| ML Engineer      | FULL ALLOW       | FULL ALLOW        | LOCAL ONLY         |
| Auditor / Viewer | DENIED           | READ-ONLY         | DENIED             |
+------------------+------------------+-------------------+--------------------+
```

---

## 3. Functional Requirements

### FR-001: Model & Tokenizer Initialization
- **System Action**: The system shall load Causal Language Models via `AutoModelForCausalLM` and `AutoTokenizer` with device placement onto `cuda` or `cpu`.
- **Validation**:
  - `tokenizer.pad_token_id` MUST be initialized to `tokenizer.eos_token_id` if missing.
  - `<|endoftext|>` stop token encoding MUST equal `tokenizer.eos_token_id`.
  - `model.generation_config` MUST be synchronized with tokenizer token IDs.

### FR-002: Supervised Fine-Tuning (SFT) Execution
- **System Action**: The system shall execute single-turn or multi-turn instruction fine-tuning using `SFTTrainer`.
- **Criteria**:
  - Effective batch size = `per_device_train_batch_size` × `gradient_accumulation_steps`.
  - Gradient computation MUST support `bf16` / `fp16` mixed precision.
  - Evaluation checkpoints MUST be saved to `trainer_output/` with step indices.

### FR-003: Direct Preference Optimization (DPO) Execution
- **System Action**: The system shall compute DPO loss over paired prompt-chosen-rejected tuples without requiring an explicit reward model network.
- **Criteria**:
  - Support configurable implicit reward parameter $\beta \in [0.01, 0.5]$.
  - Log implicit chosen/rejected rewards and reward margins per logging step.

### FR-004: Group Relative Policy Optimization (GRPO) Execution
- **System Action**: The system shall generate $G$ completions per prompt, score completions using rule-based reward functions, normalize advantages group-wise, and update policy parameters.
- **Criteria**:
  - Group size $G \ge 4$ (default $G=8$).
  - Reward functions MUST return scalar scores $r \in [0.0, 1.0]$.
  - Normalized advantage $A_i = \frac{r_i - \text{mean}(R)}{\text{std}(R) + \epsilon}$.

### FR-005: Forward KL & Retention Metrics Evaluation
- **System Action**: The system shall calculate token-level Forward KL divergence between post-trained policy $\pi_\theta$ and reference base policy $\pi_{\text{base}}$.
- **Criteria**:
  - $D_{\text{KL}}(\pi_\theta \| \pi_{\text{ref}}) = \sum_{t} \pi_\theta(y_t \mid x, y_{<t}) \left( \log \pi_\theta(y_t \mid x, y_{<t}) - \log \pi_{\text{ref}}(y_t \mid x, y_{<t}) \right)$.
  - Export structured JSON logs to `trainer_output/kl_runs.json`.

---

## 4. Business Rules & Field Validation Rules

1. **VRAM Safety Constraint**: Batch size and sequence length configurations MUST NOT exceed 95% of available GPU memory capacity.
2. **Dataset Format Validation**: Datasets MUST conform to standard HuggingFace `messages` format (`[{"role": "user", "content": "..."}, {"role": "assistant", "content": "..."}]`).
3. **Reward Bounds**: All custom GRPO reward functions MUST produce finite numerical values (no `NaN` or `Inf`).

---

## 5. Security, Privacy & Encryption Specifications

- **Transport Security**: HTTPS / TLS 1.3 enforced for model downloads from HuggingFace Hub.
- **Secrets Management**: Environment tokens (`HF_TOKEN`, `WANDB_API_KEY`) MUST be read from environment variables or `.env` files and NEVER committed to version control.
- **Container Isolation**: Docker images run as non-root unprivileged execution contexts where applicable.

---

## 6. Non-Functional Performance Thresholds

```
+------------------------------------+-------------------------------------------+
| ATTRIBUTE                          | SPECIFICATION                             |
+------------------------------------+-------------------------------------------+
| Peak Memory Usage                  | < 8.0 GB VRAM (135M Model)                |
| Model Load Time                    | < 5.0 seconds (Local cache hit)           |
| Training Throughput                | > 45 tokens/sec (RTX 4090 / 3090)         |
| Dashboard API Latency              | < 50 ms (Nginx static proxy response)     |
| Service Availability               | 99.9% Uptime (Containerized worker)       |
+------------------------------------+-------------------------------------------+
```

---

## 7. System Acceptance Criteria

- **AC-SRS-01**: All training scripts (`src/identity_sft.py`, `src/dpo.py`, `src/grpo_countdown.py`) execute without error and produce valid model checkpoints.
- **AC-SRS-02**: `pyproject.toml` dependencies resolve cleanly with `uv sync`.
- **AC-SRS-03**: Docker container builds cleanly via `docker-compose up --build`.
