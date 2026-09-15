# Product Requirement Document (PRD)

## Project: NanoAlign (Minimal LLM Post-Training & Alignment Framework)
**Author**: Nachiket Gadilohar ([nachiketlohar0306@gmail.com](mailto:nachiketlohar0306@gmail.com))  
**GitHub**: [github.com/nachiket0987/NanoAlign](https://github.com/nachiket0987/NanoAlign)  
**LinkedIn**: [linkedin.com/in/nachiket-gadilohar-profile/](https://linkedin.com/in/nachiket-gadilohar-profile/)  
**Status**: Approved Specification  
**Version**: 1.0.0  

---

## 1. Executive Summary & Problem Statement

### 1.1 Executive Summary
Large Language Model (LLM) post-training — spanning Supervised Fine-Tuning (SFT), Direct Preference Optimization (DPO), and Group Relative Policy Optimization (GRPO) — is essential for transforming raw base completion models into aligned, instruction-following, and reasoning-capable assistants. However, state-of-the-art RLHF/post-training stacks typically require massive GPU clusters, closed proprietary tooling, and complex distributed orchestrators.

**NanoAlign** bridges this gap by providing an open-source, minimal, and fully reproducible LLM post-training and evaluation framework optimized for consumer GPUs (starting at a single 8GB VRAM card). It equips researchers and engineers with standard algorithms, KL-divergence tracking metrics, and rule-based reward functions to observe catastrophic forgetting, RL drift minimization ("RL's Razor"), and DeepSeek-R1 style reasoning amplification.

### 1.2 Problem Statement
- **Extreme Hardware Barriers**: Traditional RLHF (PPO) requires maintaining 4 concurrent neural networks (Policy, Value/Critic, Reference, and Reward models), demanding 40GB–80GB+ GPUs.
- **Opacity of Distribution Drift**: Practitioners lack simple, standardized tools to measure how much SFT versus RL distorts the baseline language model's pre-trained knowledge distribution.
- **Complexity of CoT Reasoning**: Reproducing self-correction and reasoning "aha moments" in small models (0.14B–3B parameters) lacks lightweight, reproducible reference implementations.

---

## 2. Target User Personas & Value Proposition Matrix

| User Persona | Key Pain Points | NanoAlign Solution & Value |
| :--- | :--- | :--- |
| **AI Researcher / Academic** | High GPU cost for RLHF experiments; inability to track token-level KL drift. | Runs SFT, DPO, and GRPO on single 8GB GPU; automated Forward KL divergence & IFEval tracking. |
| **LLM Engineer in Enterprise** | Complex PPO setup; loss of general language capability after SFT. | Light-weight GRPO without critic networks; "RL's Razor" benchmark proves lower drift than SFT. |
| **Open-Source Developer** | Bloated frameworks (Deepspeed, Ray) hard to inspect in single-day hacks. | Core modules implemented in <100 lines of clean PyTorch + HuggingFace TRL code. |

---

## 3. Product Goals & Quantitative Success Metrics (KPIs)

### 3.1 Primary Goals
1. **Accessibility**: Run full post-training pipelines on consumer 8GB GPUs without OOM errors.
2. **Precision Evaluation**: Provide exact Forward KL divergence measurements ($D_{\text{KL}}(\pi_{\text{ft}} \| \pi_{\text{base}})$) alongside benchmark metrics (IFEval satisfaction, Perplexity retention).
3. **Reasoning Amplification**: Reproduce stable search and self-verification strategy emergence on Countdown and GSM8K reasoning benchmarks using GRPO.

### 3.2 Key Performance Indicators (KPIs)

```
+-----------------------------------------------------------------------------------+
| METRIC                           | TARGET THRESHOLD                               |
+----------------------------------+------------------------------------------------+
| Minimum VRAM Requirement         | <= 7.8 GB VRAM (135M Model SFT/DPO/GRPO)       |
| Throughput (Tokens/Second)       | >= 45.0 tok/s (SmolLM2-135M on RTX 30/40 series)|
| Time-To-First-Token (TTFT)       | <= 120 ms                                      |
| GRPO vs SFT Forward KL Drift     | GRPO KL <= 0.12 vs SFT KL >= 0.28 (at equal skill)|
| Test Suite Coverage              | >= 85% Code Coverage                           |
+----------------------------------+------------------------------------------------+
```

---

## 4. Core MVP Features & Scope Matrix

### 4.1 In-Scope Features (MVP)
- **SFT Module (`src/identity_sft.py`)**: Teacher forcing cross-entropy fine-tuning with gradient accumulation and memory optimization.
- **DPO Module (`src/dpo.py`)**: Direct Preference Optimization using paired preference data without reward modeling.
- **GRPO Module (`src/grpo_countdown.py`)**: Group Relative Policy Optimization with rule-based reward functions (format verification + math correctness).
- **KL Divergence Engine (`src/kl_analysis.py`)**: Exact forward KL evaluation against reference baseline models.
- **Language Retention & Perplexity (`src/ppl_eval.py`, `src/retention_eval.py`)**: Measuring held-out language quality decay.
- **Docker Containerization**: Multi-stage Dockerfile and Docker Compose environment with optional vLLM extra.

### 4.2 Out-of-Scope Features for MVP
- PPO actor-critic network setup (superseded by GRPO).
- Multi-node distributed clusters across thousands of GPUs (focus is single-node 1x-8x GPU).
- Native iOS/Android SDK bindings (backend CLI & Python API only).

---

## 5. User Stories

- **US-01 (SFT Alignment)**: *As an AI Engineer, I want to fine-tune a 135M model on single-turn instruction pairs on an 8GB GPU so that the model reliably adopts target identity and formatting.*
- **US-02 (GRPO Reasoning)**: *As a Researcher, I want to apply GRPO with a rule-based Countdown reward function so that the model learns chain-of-thought self-verification without external reward models.*
- **US-03 (KL Drift Measurement)**: *As a Lead Data Scientist, I want to compare token-level KL divergence between SFT and GRPO checkpoints so that I can quantify catastrophic forgetting.*

---

## 6. Technical Assumptions & Constraints

- **Python Runtime**: Python >= 3.12 managed via `uv`.
- **GPU Hardware**: Minimum 8GB VRAM (NVIDIA CUDA >= 12.8 compatible driver).
- **Deep Learning Stack**: PyTorch >= 2.6, HuggingFace Transformers 4.x, HuggingFace TRL >= 0.18, PEFT 0.17.x.

---

## 7. Risk Management & Mitigation Matrix

| Risk Event | Severity | Impact | Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **CUDA Out Of Memory (OOM)** | High | Training crash | Use gradient accumulation steps (4-8), mixed precision (bf16), per-device batch size = 8. |
| **Tokenizer EOS Stop Mismatch** | Medium | Infinite generation loops | Enforce explicit `generation_config` synchronization and EOS sanity assertions in `model_loader.py`. |
| **Dependency Conflicts in vLLM** | Medium | Installation failure on Python 3.14 | Pin `vllm>=0.16,<0.17` as an optional extra (`uv sync --extra vllm`). |

---

## 8. Testable Acceptance Criteria Matrix

| Feature ID | Feature Name | Testable Acceptance Criteria |
| :--- | :--- | :--- |
| **AC-001** | SFT Execution | Successfully trains SmolLM2-135M for 1 epoch within 8GB VRAM; loss decreases monotonously. |
| **AC-002** | GRPO Reward Scaling | Reward curve on Countdown task increases from ~0.15 to >=0.75 over 200 steps. |
| **AC-003** | KL Computation | `kl_analysis.py` computes non-negative mean per-token Forward KL with zero variance on identical models. |
