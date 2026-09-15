# System Architecture Document (SAD)

## Project: NanoAlign
**Author**: Nachiket Gadilohar ([nachiketlohar0306@gmail.com](mailto:nachiketlohar0306@gmail.com))  
**Repository**: [github.com/nachiket0987/NanoAlign](https://github.com/nachiket0987/NanoAlign)  
**Document Version**: 1.0.0  

---

## 1. System Overview & Tech Stack Table

NanoAlign is designed around a modular, decoupled architecture where training algorithms, reward verification engines, dataset loaders, and plotting/evaluation modules operate independently.

| Layer | Component | Technology / Library |
| :--- | :--- | :--- |
| **Language / Runtime** | Core Runtime | Python 3.12, PyTorch 2.6+ (cu128) |
| **Package Manager** | Dependency Resolver | Astral `uv` |
| **LLM Engine** | Model & Tokenizer | HuggingFace `transformers`, `peft` |
| **Alignment Trainers**| SFT / DPO / GRPO | HuggingFace `trl` |
| **Inference Acceleration**| Rollout Engine | Optional `vllm` 0.16.x |
| **Evaluation & Telemetry**| Benchmark Engine | `lm-eval`, `matplotlib`, `rich` |
| **Containerization** | Infrastructure | Docker, Docker Compose, Nginx |

---

## 2. System Architecture Diagram

```mermaid
graph TB
    subgraph Storage ["Data & Model Storage Layer"]
        HFHub["HuggingFace Hub"]
        DataDir["Dataset Cache (JSON / Arrow)"]
        OutputDir["Checkpoint Storage (trainer_output/)"]
    end

    subgraph CoreEngine ["NanoAlign Core Engine (src/)"]
        ModelLoader["Model Loader & Tokenizer Sync (model_loader.py)"]
        DataLoader["Dataset Loader (data_loader.py)"]
        
        subgraph AlgModule ["Alignment Algorithms"]
            SFT["SFT Engine (identity_sft.py / sft.py)"]
            DPO["DPO Engine (dpo.py)"]
            GRPO["GRPO Engine (grpo_countdown.py / grpo_cot.py)"]
        end
        
        subgraph RewardModule ["Rule Reward Verifiers"]
            RewardCD["Countdown Rewards (countdown_rewards.py)"]
            RewardGSM["GSM8K Rewards (gsm8k_rewards.py)"]
            RewardIF["IFEval Rewards (ifeval_rewards.py)"]
        end
        
        subgraph EvalModule ["Evaluation & Plotting"]
            KLEval["KL Divergence Tracker (kl_analysis.py)"]
            PPLEval["Perplexity Evaluator (ppl_eval.py)"]
            Plotter["Matplotlib Plotter (src/post-plot/)"]
        end
    end

    HFHub --> ModelLoader
    DataDir --> DataLoader
    ModelLoader --> AlgModule
    DataLoader --> AlgModule
    AlgModule --> RewardModule
    AlgModule --> OutputDir
    OutputDir --> EvalModule
    EvalModule --> Plotter
```

---

## 3. Data Flow Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    actor User as Engineer / Script
    participant Loader as model_loader.py
    participant Trainer as GRPO Trainer (trl)
    participant Model as SmolLM2 Policy
    participant Reward as countdown_rewards.py
    participant Disk as trainer_output/

    User->>Loader: load_model_and_tokenizer("SmolLM2-135M")
    Loader->>Loader: Sync EOS/PAD tokens & generation config
    Loader-->>Trainer: Return model, tokenizer
    
    loop Training Epochs (Steps 1..N)
        Trainer->>Model: Sample G=8 completions per prompt
        Model-->>Trainer: Generated token completions
        Trainer->>Reward: Evaluate reward_func(completions, targets)
        Reward-->>Trainer: Return scalar reward vector [r_1 .. r_8]
        Trainer->>Trainer: Compute group advantage A_i = (r_i - mean)/std
        Trainer->>Model: Backprop policy loss - A_i * log_prob
    end
    
    Trainer->>Disk: Save checkpoint & training metrics JSON
    User->>Disk: Run kl_analysis.py on saved checkpoint
```

---

## 4. Package & Component Breakdown

```
NanoAlign/
├── Dockerfile                  # Multi-stage GPU container definition
├── docker-compose.yml          # Container orchestration suite
├── nginx.conf                  # Nginx proxy for metric dashboards
├── pyproject.toml              # UV project definition & dependencies
├── README.md                   # Executive documentation
├── docs/                       # Engineering Specification Suite
│   ├── PRD.md
│   ├── SRS.md
│   ├── ARCHITECTURE.md
│   ├── UI_UX_DESIGN.md
│   └── DEVELOPMENT_PLAN.md
├── assets/                     # Generated charts & visual graphics
│   └── figures/
└── src/                        # Core Python Package
    ├── __init__.py             # Package init & dprint debug switch
    ├── model_loader.py         # Model loading & generation timing
    ├── data_loader.py          # Data ingestion utilities
    ├── identity_sft.py         # 135M SFT experiment baseline
    ├── sft.py                  # Standard SFT pipeline
    ├── dpo.py                  # Direct Preference Optimization
    ├── grpo_countdown.py       # GRPO Countdown reasoning trainer
    ├── countdown_rewards.py    # Equation format & target check reward
    ├── kl_analysis.py          # Forward KL divergence engine
    ├── ppl_eval.py             # Language retention evaluator
    └── post-plot/              # Publication graphic generators
        ├── razor_pareto.py
        ├── countdown_curve.py
        └── ppl_forgetting.py
```

---

## 5. Security & Deployment Architecture

- **Isolated Execution**: Containers run with explicit GPU reservations via Docker Compose device mappings.
- **Stateless Verification**: Reward engines execute in pure Python memory without external database or RPC network overhead.
- **CI/CD Integration**: Pre-commit hooks validate formatting via `ruff` and imports via `pyright`.
