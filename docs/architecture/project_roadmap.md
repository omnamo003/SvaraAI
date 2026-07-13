# ShivaAI Implementation Roadmap & Backlog
**Version**: 1.0.0  
**Status**: DRAFT BACKLOG  

---

## Epic 1: Enterprise Authentication & Access Control

### Feature: User Registration & Lifecycle
Core user registration, email validation workflow, and password recovery.

#### Task 1: Initialize Database Tables & Schemas
* **Estimated Effort**: 4 hours (1 Story Point)
* **Dependencies**: None
* **Subtasks**:
  1. Define SQLModel schemas for `users` and `organizations`.
  2. Implement database sessions helper (`get_session`).
  3. Create Alembic migration script for tables creation.
* **Acceptance Criteria**:
  - PostgreSQL database contains `users` and `organizations` tables with primary keys, unique fields, and indexes.
  - Session generator yields a clean, thread-safe session.
* **Testing Requirements**:
  - Write test asserting table existence.
  - Run database migration test to assert clean rollback.

#### Task 2: Implement Signup & Email Verification API
* **Estimated Effort**: 8 hours (2 Story Points)
* **Dependencies**: Task 1
* **Subtasks**:
  1. Build `/api/v1/auth/signup` endpoint.
  2. Implement JWT token signature for email verification payload.
  3. Integrate mock email dispatcher service (using SMTP/Console mock).
  4. Build `/api/v1/auth/verify` verification validation endpoint.
* **Acceptance Criteria**:
  - `POST /api/v1/auth/signup` registers a user and triggers verification token.
  - `GET /api/v1/auth/verify` sets `is_verified=true` in PostgreSQL.
* **Testing Requirements**:
  - Run integration test asserting verify code changes database verification flag.
  - Assert HTTP 400 response code on expired verify tokens.

---

### Feature: JWT Session Management & Rotation
Security token lifecycle, logins, logouts, and token rotations.

#### Task 3: Develop Direct Bcrypt Passwords Hashing
* **Estimated Effort**: 2 hours (0.5 Story Points)
* **Dependencies**: Task 1
* **Subtasks**:
  1. Write direct `bcrypt` password hash extraction functions.
  2. Write password matches validation check utility.
* **Acceptance Criteria**:
  - Raw passwords are never exposed in cleartext.
  - High-entropy password checks enforce correct validations.
* **Testing Requirements**:
  - Unit test verifying hashing results do not match original string.
  - Assert verification returns true for correct match, false for mismatch.

#### Task 4: Token Generation & Session Caching (Redis)
* **Estimated Effort**: 8 hours (2 Story Points)
* **Dependencies**: Task 2, Task 3
* **Subtasks**:
  1. Implement RS256 token signing utility.
  2. Expose JWKS endpoint (`/.well-known/jwks.json`) for signature validation.
  3. Configure Redis cache store to index session hashes.
  4. Write `/api/v1/auth/login` endpoint to return JWT and set secure HTTP-only refresh cookie.
* **Acceptance Criteria**:
  - Successful login returns signed RS256 JWT access token.
  - Refresh token cookie is set with HttpOnly, Secure, and SameSite=Strict flags.
* **Testing Requirements**:
  - Test verifying JWT payload claims.
  - Assert that login credentials mismatch returns HTTP 401.

#### Task 5: Refresh Token Rotation (RTR) & Logout
* **Estimated Effort**: 6 hours (1.5 Story Points)
* **Dependencies**: Task 4
* **Subtasks**:
  1. Implement `/api/v1/auth/refresh` parsing rotation checks.
  2. Program automatic revocation of all user sessions if a replayed refresh token is detected.
  3. Build `/api/v1/auth/logout` endpoint.
* **Acceptance Criteria**:
  - Refreshing tokens returns a new token pair and revokes the old one.
  - Logout flags session as revoked in Redis.
* **Testing Requirements**:
  - Replay token twice to trigger session revocation test.
  - Validate database session status is updated to `revoked=true` on logout.

---

## Epic 2: Text-to-Speech (TTS) Inference Engine

### Feature: Model Abstraction Layer & Inferencing
Decoupling underlying models from the API gateway routing.

#### Task 1: Create Model Base Interface & Mock Adapter
* **Estimated Effort**: 4 hours (1 Story Point)
* **Dependencies**: None
* **Subtasks**:
  1. Define abstract `BaseTTSModel` class.
  2. Implement `MockTTSModel` simulating inference times and output.
* **Acceptance Criteria**:
  - Inference base class enforces parameters (text, speed, pitch, embedding).
  - Mock model returns valid `.wav` file structure.
* **Testing Requirements**:
  - Unit test verifying mock model returns audio byte array.

#### Task 2: Integrate GPU Celery Task Worker
* **Estimated Effort**: 8 hours (2 Story Points)
* **Dependencies**: Task 1
* **Subtasks**:
  1. Configure Celery queues (`tts_fast`, `tts_bulk`).
  2. Write celery task wrapper `generate_tts_task`.
  3. Integrate container model weight preloading script.
* **Acceptance Criteria**:
  - GPU worker starts with `concurrency=1` and preloads model weights.
  - Celery processes tasks from separate queues independently.
* **Testing Requirements**:
  - Mock Celery worker run asserting task execution and audio generation.

---

### Feature: Jobs Pipeline & Storage
Managing synthesis requests and uploading output results.

#### Task 3: Develop Jobs CRUD & Check API
* **Estimated Effort**: 6 hours (1.5 Story Points)
* **Dependencies**: Task 2
* **Subtasks**:
  1. Create `jobs` table in PostgreSQL.
  2. Expose `POST /api/v1/tts/synthesize` endpoint (returns Job ID, status `queued`).
  3. Expose `GET /api/v1/tts/jobs/{id}` for polling.
* **Acceptance Criteria**:
  - Job submission triggers Celery queue dispatch.
  - Polling returns correct status changes (`queued` -> `processing` -> `completed`/`failed`).
* **Testing Requirements**:
  - End-to-end integration test pushing a job and validating status progression.

#### Task 4: Integrate MinIO Audio Storage Client
* **Estimated Effort**: 4 hours (1 Story Point)
* **Dependencies**: Task 3
* **Subtasks**:
  1. Build boto3 S3 / MinIO client wrapper.
  2. Program bucket initialization check at startup.
  3. Implement file upload and presigned URL generation.
* **Acceptance Criteria**:
  - Completed TTS audio waveforms are saved to the `svara-audio` bucket.
  - Gateway returns a valid presigned URL for downloading.
* **Testing Requirements**:
  - Assert correct bucket creation.
  - Test download of uploaded WAV file.

---

## Epic 3: Voice Library & Vector DB

### Feature: Embeddings Storage & Similarity Search
Vector-based storage and query systems for speaker profiles.

#### Task 1: Integrate pgvector DB Indexing
* **Estimated Effort**: 6 hours (1.5 Story Points)
* **Dependencies**: Epic 1 Task 1
* **Subtasks**:
  1. Add `pgvector` migration.
  2. Define `voice_versions` table with a 512-dimension vector data type.
  3. Configure HNSW index on the vector embedding column.
* **Acceptance Criteria**:
  - `voice_versions` table is successfully created.
  - Cosine distance operations can run natively in PostgreSQL.
* **Testing Requirements**:
  - SQL test executing cosine distance search between mock vector rows.

#### Task 2: Create Voice Access Control (ACL)
* **Estimated Effort**: 8 hours (2 Story Points)
* **Dependencies**: Task 1
* **Subtasks**:
  1. Create `voice_permissions` table in DB.
  2. Implement validation check helper in `deps.py`.
  3. Create Voice Share endpoint `POST /api/v1/voices/{id}/share`.
* **Acceptance Criteria**:
  - Team or direct user permissions regulate voice reads/writes.
  - Share endpoint adds valid constraints mapping.
* **Testing Requirements**:
  - Integration test asserting a user cannot access another organization's or team's private voice.

---

## Epic 4: Developer API Platform

### Feature: API Platform Management & Security
Developer rate limits, webhooks, and request idempotency.

#### Task 1: API Key Authorization & Hashing
* **Estimated Effort**: 6 hours (1.5 Story Points)
* **Dependencies**: Epic 1 Task 4
* **Subtasks**:
  1. Create `api_keys` table.
  2. Implement prefix generation and SHA-256 database key hashing.
  3. Write `X-API-KEY` header check dependency.
* **Acceptance Criteria**:
  - Key secret string is only returned once on generation.
  - Database holds only the SHA-256 hash of keys.
* **Testing Requirements**:
  - Test verifying validation using hashed keys works correctly.

#### Task 2: Implement Redis Sliding Window Rate Limiter
* **Estimated Effort**: 8 hours (2 Story Points)
* **Dependencies**: Task 1
* **Subtasks**:
  1. Write Redis Lua script for sliding window request limit tracking.
  2. Create rate limiter middleware in FastAPI.
  3. Append X-RateLimit headers to responses.
* **Acceptance Criteria**:
  - Requests exceeding limit trigger HTTP 429.
  - Headers return remaining limits accurately.
* **Testing Requirements**:
  - Concurrency test sending bursts of calls to trigger rate limiting block.

#### Task 3: Develop API Request Idempotency
* **Estimated Effort**: 6 hours (1.5 Story Points)
* **Dependencies**: Epic 2 Task 3
* **Subtasks**:
  1. Add `Idempotency-Key` header verification middleware.
  2. Write Redis cached response logic.
* **Acceptance Criteria**:
  - Re-sending requests with the same key returns the cached response.
  - Locks prevent concurrent duplicate processing runs.
* **Testing Requirements**:
  - Assert that multiple duplicate calls trigger only a single database job record.

---

## Epic 5: SaaS Billing Engine

### Feature: Credit Quotas & Subscription Management
Accounting character consumption and checking thresholds.

#### Task 1: Redis Quota Allocation & Decrement
* **Estimated Effort**: 6 hours (1.5 Story Points)
* **Dependencies**: Epic 1 Task 1, Epic 4 Task 2
* **Subtasks**:
  1. Create Redis keys `quota:<org_id>` for remaining credits.
  2. Write atomic decrement checks prior to enqueuing synthesis jobs.
* **Acceptance Criteria**:
  - Quota checks return blocked status if remaining credits are insufficient.
  - Real-time balances match expected values during concurrent processing.
* **Testing Requirements**:
  - Test concurrent requests to assert quota limits block double-spending.

#### Task 2: Stripe Integration & Invoicing
* **Estimated Effort**: 12 hours (3 Story Points)
* **Dependencies**: Task 1
* **Subtasks**:
  1. Implement Stripe Webhook event processing.
  2. Create custom plans in Stripe dashboard and map to DB plans.
  3. Write periodic cron task to construct monthly usage invoices.
* **Acceptance Criteria**:
  - Webhooks successfully update user subscription status (active/canceled).
  - Invoices reflect exact overages character costs.
* **Testing Requirements**:
  - Mock Stripe webhook events in test suit verifying local database updates.

---

## Epic Backlog Summary (Remaining Modules)

| Epic | Feature | Key Tasks | Effort (Est) |
| :--- | :--- | :--- | :--- |
| **Epic 6: Web UI** | Dashboard Core | - Sidebar layout & routing setup<br>- Dark/Light mode implementation | 12h |
| | Voice Studio UI | - Interactive script player<br>- Parameter slider inputs | 16h |
| **Epic 7: Cloning** | Liveness Checks | - ASR verify transcript match<br>- SNR verification gate | 14h |
| | Embedding Encoder | - Integration of open-source ref model<br>- Vector generation pipeline | 16h |
| **Epic 8: DevOps** | Setup Nginx SSL | - Map domains, set TLS 1.3 | 8h |
| | Auto-scaling | - KEDA setup for Celery queues | 16h |
| | Monitor Systems | - Prometheus integration & metrics | 10h |
