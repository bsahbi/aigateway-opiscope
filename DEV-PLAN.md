# OpiScopeAIGateway — Development Plan

> Derived from `OpiScopeAIGateway-design.md`. Each task below maps to a GitHub issue.
> Phases follow the design doc's phased delivery model.

---

## Phase 0 — Infrastructure Spike

**Goal:** Validate that standalone llama-server + Qwen works from Hercule without Hermes.

| # | Task | Verification |
|---|------|-------------|
| 0.1 | Install standalone llama.cpp/llama-server | Binary runs, `--help` works |
| 0.2 | Load Qwen3.5-4B-Q4_K_M model | Model loads, `/v1/models` lists it |
| 0.3 | Bind llama-server to fixed LAN/private interface and port | Listening on configured `host:port`, not exposed to public internet |
| 0.4 | Verify `/v1/models` endpoint | Returns valid JSON with model list |
| 0.5 | Verify `/v1/chat/completions` endpoint | Returns a valid completion |
| 0.6 | Call llama-server from Hercule | HTTP request succeeds from Hercule host |
| 0.7 | Measure basic latency and tokens/sec | TTFT and throughput recorded |
| 0.8 | Confirm stability | Sustained requests without crashes |

**Success criterion:** `Hercule -> llama-server -> Qwen` works reliably without Hermes.

---

## Phase 1 — LiteLLM

**Goal:** Deploy LiteLLM as the provider abstraction layer.

| # | Task | Verification |
|---|------|-------------|
| 1.1 | Deploy LiteLLM | LiteLLM container/service running |
| 1.2 | Configure `opiscope-local` model mapped to llama-server | Model config in `config.yaml` |
| 1.3 | Test `Hercule -> LiteLLM -> llama-server -> Qwen` flow | Chat completion works through LiteLLM |

**Success criterion:** OpiScope can use the OpenAI-compatible LiteLLM endpoint without knowing the inference implementation.

---

## Phase 2 — OpiScopeAIGateway MVP

**Goal:** Minimum viable gateway with auth, chat, streaming, and error handling.

| # | Task | Verification |
|---|------|-------------|
| 2.1 | Repository structure setup | `src/`, `tests/`, `infra/` directories created per design doc §17 |
| 2.2 | Health endpoint (`GET /health`) | Returns gateway + provider + model health status |
| 2.3 | Authentication boundary | Caller identity verified |
| 2.4 | Chat endpoint (`POST /api/v1/chat`) | Accepts surveyId, conversationId, message |
| 2.5 | Streaming support (SSE) | Token streaming to client |
| 2.6 | Conversation ID management | Multi-turn state maintained |
| 2.7 | Basic survey authorization | User can only access authorized surveys |
| 2.8 | Basic context builder | Assembles survey metadata + questions into prompt |
| 2.9 | Provider abstraction (`AIProvider` interface) | `LiteLLMProvider` implements the interface |
| 2.10 | Structured error model | Provider-neutral error codes returned |
| 2.11 | Logging/request IDs | Every request has a traceable ID |
| 2.12 | Configuration externalized | Model, gateway URL, llama-server address via env/config |
| 2.13 | Docker/deployment setup | `docker-compose.yml` with gateway + litellm services |
| 2.14 | No secrets in git | `.env.example` only, `.env` gitignored |

**Success criterion:** `Ask OpiScope -> OpiScopeAIGateway -> LiteLLM -> llama-server -> Qwen` with streaming, auth, and clean errors.

---

## Phase 3 — Survey Context

**Goal:** Inject real survey data into the LLM context.

| # | Task | Verification |
|---|------|-------------|
| 3.1 | Survey metadata integration | Survey title, description, dates in context |
| 3.2 | Survey questions integration | Question text and types in context |
| 3.3 | Response statistics integration | Counts, percentages, breakdowns in context |
| 3.4 | Authorized database context | DB queries scoped to user's authorized survey scope |

**Success criterion:** LLM receives controlled, authorized survey data in context.

---

## Phase 4 — RAG

**Goal:** Add unstructured knowledge retrieval.

| # | Task | Verification |
|---|------|-------------|
| 4.1 | Document ingestion pipeline | PDF/docs can be uploaded and processed |
| 4.2 | Chunking strategy | Documents split into retrievable chunks |
| 4.3 | Embeddings generation | Chunks embedded with configurable model |
| 4.4 | Vector store setup | Embeddings stored and queryable |
| 4.5 | Retrieval + context builder integration | Relevant chunks injected into LLM context |

**Success criterion:** Unstructured documents retrievable and injected into context without the provider knowing RAG exists.

---

## Phase 5 — AI Tools

**Goal:** Add controlled tool invocation for the LLM.

| # | Task | Verification |
|---|------|-------------|
| 5.1 | `get_survey_summary` tool | Returns survey summary via OpiScope service |
| 5.2 | `get_question_results` tool | Returns per-question results |
| 5.3 | `get_demographic_breakdown` tool | Returns demographic breakdowns |
| 5.4 | `compare_segments` tool | Compares survey segments |
| 5.5 | `search_knowledge` tool | Searches RAG knowledge base |
| 5.6 | `generate_report` tool | Triggers report generation |

**Success criterion:** LLM can invoke tools through OpiScope-controlled services, never touching DB/filesystem directly.

---

## Phase 6 — Observability & Hardening

**Goal:** Production-readiness.

| # | Task | Verification |
|---|------|-------------|
| 6.1 | Telemetry: latency, TTFT, throughput | Metrics observable |
| 6.2 | Telemetry: input/output token counts | Token usage tracked |
| 6.3 | Telemetry: error rates and types | Errors categorized and logged |
| 6.4 | Context-length monitoring | Overflow events detected and logged |
| 6.5 | Fallback strategy (design) | Document fallback path for cloud model |

---

## Definition of Done (MVP)

From design doc §23:

- [ ] Hermes is completely irrelevant to OpiScope inference
- [ ] llama-server runs independently
- [ ] llama-server has a stable configured endpoint
- [ ] Hercule can reach llama-server over the private LAN
- [ ] LiteLLM successfully proxies requests to llama-server
- [ ] OpiScopeAIGateway successfully calls LiteLLM
- [ ] Ask OpiScope can stream an answer
- [ ] Provider-specific implementation details are hidden from Ask OpiScope
- [ ] Authentication/authorization boundaries exist
- [ ] Survey context can be injected in a controlled way
- [ ] Errors are provider-neutral
- [ ] Health checks work
- [ ] Configuration is externalized
- [ ] No secrets are committed
- [ ] The system can replace Qwen/llama.cpp later without changing Ask OpiScope
