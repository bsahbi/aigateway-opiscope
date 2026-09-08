# OpiScopeAIGateway — Architecture & Implementation Specification

## 1. Purpose

OpiScopeAIGateway is the internal AI orchestration service for the OpiScope platform.

Its purpose is to provide a stable OpiScope-specific AI interface while keeping the underlying LLM infrastructure replaceable.

The gateway MUST NOT be tightly coupled to Hermes, its process manager, or any vendor-specific inference runtime.

Initial target architecture:

```text
Ask OpiScope UI
       |
       v
OpiScopeAIGateway
       |
       | OpenAI-compatible API
       v
LiteLLM Gateway
       |
       +------------------+
       |                  |
       v                  v
standalone llama-server   future providers
Qwen3.5-4B                vLLM / Ollama / cloud
```

The design should allow the inference backend to change without requiring changes to the Ask OpiScope application.

---

## 2. Architectural Principles

### 2.1 Provider independence

The application must not assume that inference is provided by:

- Hermes
- llama.cpp
- Ollama
- vLLM
- OpenAI
- any other specific provider

The AI service communicates with an internal provider abstraction.

### 2.2 No dependency on Hermes infrastructure

Hermes Desktop may continue to be used for experimentation, but OpiScopeAIGateway MUST NOT depend on:

- Hermes-managed llama-server processes
- Hermes dynamic ports
- Hermes runtime directories
- Hermes internal configuration
- Hermes process lifecycle
- undocumented Hermes APIs

Inference servers used by OpiScope must be explicitly managed by OpiScope infrastructure.

### 2.3 Prefer existing infrastructure

Do not implement an AI gateway from scratch if an existing mature open-source gateway satisfies the requirement.

Initial gateway candidate: **LiteLLM Proxy**.

A second candidate may be evaluated if necessary, e.g. Portkey Gateway.

The dev agent should validate the current capabilities and configuration of the selected OSS gateway before implementing custom equivalents.

### 2.4 OpiScope business logic stays in OpiScopeAIGateway

LiteLLM is infrastructure.

OpiScopeAIGateway owns OpiScope-specific logic such as:

- authentication
- authorization
- survey access control
- conversation management
- RAG/context assembly
- database context
- prompt construction
- tool permissions
- token/context policies
- report generation orchestration
- OpiScope-specific AI policies

Do not put OpiScope business rules into LiteLLM configuration.

---

# 3. Target System

```text
                         INTERNET
                            |
                            v
                    +----------------+
                    | Ask OpiScope   |
                    | Web UI         |
                    +-------+--------+
                            |
                            | HTTPS
                            v
                 +----------------------+
                 | OpiScopeAIGateway    |
                 |                      |
                 | Auth                 |
                 | Survey permissions   |
                 | Conversations        |
                 | RAG                  |
                 | DB context           |
                 | Prompt orchestration |
                 | Tool policy          |
                 +----------+-----------+
                            |
                            | OpenAI-compatible API
                            v
                 +----------------------+
                 | LiteLLM Proxy        |
                 |                      |
                 | Routing              |
                 | Fallbacks             |
                 | Rate limits           |
                 | Budgets               |
                 | Provider abstraction |
                 +----------+-----------+
                            |
             +--------------+--------------+
             |                             |
             v                             v
 +-----------------------+       +----------------------+
 | llama-server          |       | Future provider      |
 | Windows laptop        |       | vLLM / Ollama /      |
 | Qwen3.5-4B            |       | cloud LLM etc.       |
 +-----------------------+       +----------------------+
```

---

# 4. Initial Deployment

Initial infrastructure:

```text
Hercule
├── OpiScopeAIGateway
└── LiteLLM

Windows Qwen machine
└── standalone llama-server
    └── Qwen3.5-4B-Q4_K_M
```

The Windows machine is currently:

```text
192.168.1.10
```

The exact address must NOT be hardcoded into application code. Use configuration/environment variables.

The standalone llama-server must be independently launched and managed.

It should expose an OpenAI-compatible HTTP API on a fixed port.

Example conceptual configuration:

```text
host = 0.0.0.0
port = 8000
model = Qwen3.5-4B-Q4_K_M.gguf
```

The exact llama.cpp arguments are an infrastructure concern and should be configurable.

---

# 5. Service Boundaries

## 5.1 Ask OpiScope

Responsibilities:

- chat UI
- streaming display
- user interaction
- conversation UI
- citations/source presentation
- report presentation

It should NOT know how Qwen, llama.cpp, LiteLLM, or another model is deployed.

It communicates only with OpiScopeAIGateway.

---

## 5.2 OpiScopeAIGateway

Responsibilities:

### Authentication

Identify the caller.

### Authorization

Determine:

- which survey the user can access
- whether the survey is public/private
- which data can be exposed
- which AI capabilities are allowed
- whether benchmarking/reporting is available

### Context assembly

Build the model context from:

- survey metadata
- survey questions
- survey responses
- aggregated statistics
- RAG documents
- relevant database records
- conversation history

### Prompt orchestration

Construct system/developer/user context appropriate for the operation.

### Tool policy

Control which tools the model may invoke.

Never allow the model to directly access the database or filesystem without a controlled OpiScope tool/API boundary.

### Model invocation

Send the final model request to the provider layer.

### Streaming

Support token streaming to Ask OpiScope.

### Conversation management

Maintain enough state to support multi-turn conversations.

The exact persistence model can evolve; do not over-engineer this during the first implementation.

---

## 5.3 LiteLLM

LiteLLM is an infrastructure/provider gateway.

Use it for capabilities it already provides, such as:

- OpenAI-compatible interface
- provider routing
- model abstraction
- retries
- fallbacks
- rate limits
- budgets
- logging/observability where appropriate
- provider configuration

Do not duplicate those features in OpiScopeAIGateway unless OpiScope has a business-specific requirement.

---

## 5.4 llama-server

The initial inference provider.

Requirements:

- standalone deployment
- fixed configured port
- OpenAI-compatible API
- independently managed lifecycle
- no Hermes dependency
- Qwen3.5-4B-Q4_K_M initial model

The server must be reachable from the OpiScope infrastructure over the private LAN.

It must NOT be exposed directly to the public Internet.

---

# 6. Provider Abstraction

OpiScopeAIGateway should have an internal provider boundary.

Conceptually:

```typescript
interface AIProvider {
  chat(request: ChatRequest): AsyncIterable<ChatChunk>;
}
```

The exact implementation/language is determined by the existing OpiScope stack.

The application should not directly import llama.cpp-specific SDKs.

The first provider can be:

```text
AIProvider
    |
    v
LiteLLMProvider
    |
    v
LiteLLM
```

This keeps the application independent of the actual inference server.

---

# 7. API Design

The external OpiScopeAIGateway API should be OpiScope-oriented rather than exposing LiteLLM directly.

Initial conceptual endpoint:

```http
POST /api/v1/chat
```

Example request:

```json
{
  "surveyId": "srv_pm_fit_2026",
  "conversationId": "optional-existing-conversation-id",
  "message": "What are the main findings of this survey?"
}
```

Example streaming response:

```text
data: {"type":"message.delta","content":"The"}
data: {"type":"message.delta","content":" main"}
data: {"type":"message.delta","content":" findings"}
...
data: {"type":"message.completed"}
```

The exact transport can be SSE or another streaming mechanism compatible with the existing OpiScope frontend.

Do not expose provider-specific parameters unless there is a clear product requirement.

---

# 8. Context / RAG Architecture

The first version should support a clean context pipeline:

```text
User message
     |
     v
Authorization
     |
     v
Survey context
     |
     +---- survey metadata
     |
     +---- survey questions
     |
     +---- response statistics
     |
     +---- relevant database information
     |
     +---- RAG retrieval
     |
     +---- conversation history
     |
     v
Context builder
     |
     v
LLM request
```

The gateway should distinguish between:

### Structured context

Examples:

- survey metadata
- response counts
- demographic breakdowns
- computed statistics
- benchmark values

### Unstructured context

Examples:

- PDF documents
- research reports
- uploaded documents
- explanatory material

Structured data should come from trusted OpiScope services/database queries rather than being inferred from embeddings.

RAG should be used for unstructured knowledge.

---

# 9. Database Access

The LLM must never receive unrestricted database access.

Use controlled application services/tools:

```text
LLM
 |
 v
OpiScope tool
 |
 v
validated query/service
 |
 v
database
```

Every database-derived context operation must be scoped to the authenticated user's authorized survey/data scope.

---

# 10. Security

The inference server is private infrastructure.

Required boundaries:

```text
Public Internet
      |
      v
OpiScope application
      |
      v
OpiScopeAIGateway
      |
      v
LiteLLM
      |
      v
Private LAN
      |
      v
llama-server
```

Do NOT expose llama-server publicly.

Do NOT expose LiteLLM publicly unless there is a concrete operational reason.

Prefer:

- private network
- firewall restrictions
- API authentication between services
- secrets in environment/secret management
- no secrets committed to Git

---

# 11. Model Configuration

Model configuration must be externalized.

Do not hardcode:

```text
Qwen3.5-4B-Q4_K_M
```

into application logic.

Example configuration concept:

```env
AI_MODEL=opiscope-local
AI_GATEWAY_URL=http://litellm:4000
```

LiteLLM then maps:

```text
opiscope-local
        |
        v
llama-server
        |
        v
Qwen3.5-4B
```

This allows:

```text
opiscope-local
opiscope-large
opiscope-fast
opiscope-cloud
```

to be changed without modifying the Ask OpiScope client.

---

# 12. Fallback Strategy

Do not implement complex fallback logic in the first MVP unless needed.

Design for it.

Future example:

```text
             LiteLLM
                |
       +--------+--------+
       |                 |
       v                 v
 local Qwen          cloud model
       |
       | failure
       v
 fallback
```

The OpiScope application should simply receive a successful AI response or a well-defined error.

---

# 13. Observability

The MVP should provide enough telemetry to answer:

- Is the gateway alive?
- Is LiteLLM reachable?
- Is the inference server reachable?
- Which model handled a request?
- Request latency
- Time to first token
- Generation throughput where available
- Input/output token counts where available
- Errors
- Context length/overflow events
- Request IDs

Do not build a complete observability platform initially.

Use existing infrastructure where possible.

---

# 14. Health Checks

At minimum:

```http
GET /health
```

for OpiScopeAIGateway.

Internal checks should be able to determine:

```text
OpiScopeAIGateway
        |
        +--> LiteLLM healthy?
                    |
                    +--> llama-server reachable?
```

Health status should distinguish between:

- gateway itself healthy
- provider unavailable
- model unavailable

---

# 15. Error Handling

Errors returned to the frontend must be provider-neutral.

Bad:

```text
llama.cpp error: llama_decode failed...
```

Good:

```json
{
  "error": {
    "code": "AI_PROVIDER_UNAVAILABLE",
    "message": "The AI service is temporarily unavailable.",
    "requestId": "..."
  }
}
```

Internal logs may contain the provider-specific error.

Important error categories should include:

```text
AUTHENTICATION_FAILED
AUTHORIZATION_DENIED
SURVEY_NOT_FOUND
CONTEXT_BUILD_FAILED
RAG_FAILED
AI_PROVIDER_UNAVAILABLE
AI_REQUEST_FAILED
AI_CONTEXT_EXCEEDED
AI_TIMEOUT
RATE_LIMITED
INTERNAL_ERROR
```

---

# 16. Context-Length Strategy

Context management must be explicit.

Do not assume the configured context length of the application matches the actual model server.

The gateway should have a configurable maximum context policy.

For the initial Qwen deployment, validate:

- actual llama-server context size
- effective usable context
- prompt token count
- generation token budget
- behavior near context limits

Do not implement aggressive automatic summarization until basic context accounting is reliable.

If compression/summarization is later introduced, it should be an explicit gateway capability rather than relying on Hermes behavior.

---

# 17. Repository Structure

Suggested structure:

```text
OpiScopeAIGateway/
├── README.md
├── docker-compose.yml
├── .env.example
├── docs/
│   ├── architecture.md
│   └── api.md
├── src/
│   ├── api/
│   ├── auth/
│   ├── chat/
│   ├── context/
│   ├── rag/
│   ├── tools/
│   ├── providers/
│   ├── conversations/
│   └── health/
├── tests/
└── infra/
    └── litellm/
        └── config.yaml
```

Adapt this to the actual OpiScope repository conventions rather than blindly creating this exact tree.

---

# 18. Docker / Deployment

The gateway should be container-friendly.

Target development environment:

```text
docker compose
    |
    +-- opiscope-ai-gateway
    |
    +-- litellm
```

The llama-server on Windows can initially remain outside Docker if GPU access and operational simplicity make that preferable.

Do not force llama.cpp into Docker unless there is a concrete benefit.

---

# 19. Development Phases

## Phase 0 — Infrastructure spike

Before writing substantial application code:

1. Install standalone llama.cpp/llama-server.
2. Load Qwen3.5-4B-Q4_K_M.
3. Bind it to a fixed LAN/private interface and port.
4. Verify `/v1/models`.
5. Verify `/v1/chat/completions`.
6. Call it from Hercule.
7. Measure basic latency and tokens/sec.
8. Confirm stability.

Success criterion:

```text
Hercule -> llama-server -> Qwen
```

works reliably without Hermes.

---

## Phase 1 — LiteLLM

Deploy LiteLLM.

Configure one model:

```text
opiscope-local
```

mapped to the standalone llama-server.

Test:

```text
Hercule -> LiteLLM -> llama-server -> Qwen
```

Success criterion:

OpiScope can use the OpenAI-compatible LiteLLM endpoint without knowing the inference implementation.

---

## Phase 2 — OpiScopeAIGateway MVP

Implement:

- health endpoint
- authentication boundary
- chat endpoint
- streaming
- conversation ID
- basic survey authorization
- basic context builder
- provider abstraction
- structured error model
- logging/request IDs

Do NOT implement the full RAG system yet.

---

## Phase 3 — Survey context

Integrate:

- survey metadata
- survey questions
- response statistics
- authorized database context

Ensure the LLM only receives data the current user is allowed to access.

---

## Phase 4 — RAG

Add:

```text
documents
   ↓
ingestion
   ↓
chunking
   ↓
embeddings
   ↓
vector store
   ↓
retrieval
   ↓
context builder
```

Keep RAG behind the gateway's context abstraction.

The inference provider should not know that RAG exists.

---

## Phase 5 — AI tools

Add controlled tools such as:

```text
get_survey_summary
get_question_results
get_demographic_breakdown
compare_segments
search_knowledge
generate_report
```

Tools should execute through OpiScope-controlled services.

---

# 20. Non-Goals for MVP

Do NOT initially build:

- a custom LLM inference server
- a custom provider protocol
- a custom routing engine
- a custom rate-limit system if LiteLLM already provides it
- a custom observability stack
- complex autonomous agents
- unrestricted SQL access for the LLM
- public access to llama-server
- Hermes integration
- model training/fine-tuning infrastructure
- multi-node inference
- Kubernetes

The goal is a small, reliable foundation.

---

# 21. Critical Design Decision

The most important abstraction is:

```text
OpiScope business logic
        ≠
AI gateway infrastructure
        ≠
LLM inference runtime
```

Therefore:

```text
Ask OpiScope
      ↓
OpiScopeAIGateway
      ↓
LiteLLM
      ↓
Inference provider
```

Each layer must be replaceable.

For example, this should be possible later:

```text
Today:

OpiScopeAIGateway
        ↓
LiteLLM
        ↓
llama-server
        ↓
Qwen3.5-4B


Later:

OpiScopeAIGateway
        ↓
LiteLLM
        ↓
vLLM
        ↓
Qwen3-14B


Or:

OpiScopeAIGateway
        ↓
LiteLLM
        ↓
cloud provider
```

No Ask OpiScope rewrite should be necessary.

---

# 22. First Developer Task

The dev agent should NOT immediately start implementing a large application.

First perform a short architecture/infrastructure validation:

1. Inspect the existing OpiScope repositories and conventions.
2. Determine the appropriate language/framework for OpiScopeAIGateway.
3. Evaluate current LiteLLM OSS capabilities relevant to this architecture.
4. Create a minimal standalone llama-server deployment plan.
5. Create the smallest working vertical slice:

```text
Ask OpiScope/client
        ↓
OpiScopeAIGateway
        ↓
LiteLLM
        ↓
standalone llama-server
        ↓
Qwen3.5-4B
```

6. Verify streaming.
7. Verify errors.
8. Verify health checks.
9. Verify provider replacement can be configured without application code changes.

Only after this vertical slice works should the agent proceed with RAG, tools, advanced context management, and other features.

---

# 23. Definition of Done for MVP

The MVP is considered successful when:

- [ ] Hermes is completely irrelevant to OpiScope inference.
- [ ] llama-server runs independently.
- [ ] llama-server has a stable configured endpoint.
- [ ] Hercule can reach llama-server over the private LAN.
- [ ] LiteLLM successfully proxies requests to llama-server.
- [ ] OpiScopeAIGateway successfully calls LiteLLM.
- [ ] Ask OpiScope can stream an answer.
- [ ] Provider-specific implementation details are hidden from Ask OpiScope.
- [ ] Authentication/authorization boundaries exist.
- [ ] Survey context can be injected in a controlled way.
- [ ] Errors are provider-neutral.
- [ ] Health checks work.
- [ ] Configuration is externalized.
- [ ] No secrets are committed.
- [ ] The system can replace Qwen/llama.cpp later without changing Ask OpiScope.

---

# 24. Guiding Rule

When deciding whether to implement something:

> **If an existing mature open-source component already solves the infrastructure problem, use it. Build OpiScope-specific logic only where it creates OpiScope value.**

The goal is not to build another generic AI gateway.

The goal is to make **Ask OpiScope reliably intelligent** while keeping the underlying AI infrastructure replaceable.
