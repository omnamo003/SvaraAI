# ShivaAI Developer API Platform Specification
**Module 8**  

---

## 1. API Platform & SDK Architecture

The developer platform enables third-party applications to integrate Text-to-Speech and Voice Cloning capabilities via high-performance endpoints.

```
+---------------------------------------------------------------------------------+
|                               Developer Client                                  |
+---------------------------------------------------------------------------------+
          |                                                       |
          | HTTP (REST Control Plane)                             | WS (Realtime Streaming)
          v                                                       v
+------------------+                                     +------------------------+
|   API Gateway    |                                     |    WebSocket Server    |
|   (FastAPI)      |                                     |  (FastAPI Event Loop)  |
+------------------+                                     +------------------------+
          |                                                       |
          +--------------------------+----------------------------+
                                     |
                                     v (Validate X-API-KEY / Rate limits)
+---------------------------------------------------------------------------------+
|                                 Redis Cluster                                   |
+---------------------------------------------------------------------------------+
```

### Versioning Policy
We enforce URL versioning: `/api/v1/*`
* Deprecated features trigger standard response warning headers (`Warning: 199 - "API version v1 is deprecated and will be disabled on YYYY-MM-DD"`).

---

## 2. API Endpoints Map

### A. Authentication & Account
* `POST /api/v1/auth/token`: OAuth2 password flow token generation.

### B. Voices (Inventory)
* `GET /api/v1/voices`: List available voices (system, custom cloned).
* `POST /api/v1/voices`: Upload references to initialize a voice clone.
* `GET /api/v1/voices/{id}`: Retrieve detailed voice metadata.
* `DELETE /api/v1/voices/{id}`: Delete a custom voice profile.

### C. Text-to-Speech
* `POST /api/v1/tts/synthesize`: Trigger dynamic audio generation (202 Accepted).
* `GET /api/v1/tts/jobs/{id}`: Check synthesis task completion.

### D. Audio Stream (WebSocket)
* `WS /api/v1/tts/stream`: Real-time low-latency audio streaming endpoint.

---

## 3. Webhooks & Event Subscription

Enterprise clients can subscribe to webhook events to receive async processing updates (e.g., when a massive bulk audio job finishes).

### Webhook Event Object Schema
```json
{
  "event_id": "evt_9c18fa01-6382-411a-8cbb-1258ef9cfa12",
  "type": "tts.job.completed",
  "created_at": "2026-07-14T01:16:25Z",
  "data": {
    "job_id": "d0e40243-7f2e-4b2a-89a1-5d9c22d1df7b",
    "duration_seconds": 45.2,
    "characters": 512,
    "audio_url": "https://api.shivaai.com/v1/storage/audio/d0e40243.wav"
  }
}
```

### Webhook Security (Signing Secrets)
Every webhook request is signed. We compute a signature by applying SHA-256 HMAC over the raw JSON payload using the developer's Webhook Secret. The signature is sent in the header `X-ShivaAI-Signature`. The client verifies this header to prevent spoofing.

---

## 4. Error Handling Standard Catalog

ShivaAI standardizes errors on structural codes.

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable description.",
    "details": { ... }
  }
}
```

| HTTP Status | Error Code | Triggering Scenario |
| :--- | :--- | :--- |
| **401 Unauthorized** | `INVALID_API_KEY` | Key token fails hash matching check |
| **403 Forbidden** | `SCOPE_UNAUTHORIZED` | API key lacks permission scope for endpoint |
| **422 Unprocessable** | `CONSENT_MISSING` | Cloned voice does not have verified consent |
| **429 Too Many Requests** | `RATE_LIMIT_EXCEEDED` | Sliding window rate count exceeded |

---

## 5. SDK Architecture Roadmap

We will support native SDKs to simplify integration:

1. **Python SDK (`shivaai-python`)**:
   - Class-based API wrapper, target integration: `pip install shivaai`.
   - Supports Async and Stream hooks.
2. **JavaScript/TypeScript SDK (`@shivaai/sdk`)**:
   - Targeted for Node.js backend pipelines and React/Web client WebSockets.
3. **Core CLI Tool (`shivaai-cli`)**:
   - Command-line interface for system automation and file exports.
