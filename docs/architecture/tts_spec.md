# ShivaAI Text-to-Speech (TTS) Engine Specification
**Module 5**  

---

## 1. Engine & Model Abstraction Architecture

To support replacing open-source synthesis models with ShivaAI proprietary models without modifying core business services, we implement a **Model Abstraction Layer**.

```
+---------------------------------------------------------------------------------+
|                                 FastAPI API Core                                |
+---------------------------------------------------------------------------------+
                                         |
                                         v (Enqueues Job)
+---------------------------------------------------------------------------------+
|                                  Celery Broker                                  |
+---------------------------------------------------------------------------------+
                                         |
                                         v (Delegates to GPU Worker)
+---------------------------------------------------------------------------------+
|                             Worker Model Handler                                |
|                                                                                 |
|                      +----------------------------------+                       |
|                      |        BaseTTSModel (Class)       |                       |
|                      +----------------------------------+                       |
|                                       |                                         |
|                 +---------------------+---------------------+                   |
|                 v                                           v                   |
|   +---------------------------+               +---------------------------+     |
|   |  XTTSv2Model (Concrete)   |               |  SvaraPropModel (Future)  |     |
|   +---------------------------+               +---------------------------+     |
+---------------------------------------------------------------------------------+
```

### Class Blueprint (Model Abstraction)
```python
from abc import ABC, abstractmethod

class BaseTTSModel(ABC):
    @abstractmethod
    def load_model(self) -> None:
        """Load model weights into GPU memory."""
        pass

    @abstractmethod
    def synthesize(
        self,
        text: str,
        speaker_embedding: bytes,
        language: str,
        speed: float,
        pitch: float,
        emotion: str
    ) -> bytes:
        """Run inference and return raw audio byte array (WAV/PCM format)."""
        pass
```

---

## 2. Text-to-Speech Database Schemas

We store job metadata and execution profiles to audit performance metrics.

```sql
-- Extend Jobs table to hold precise synthesis parameters
ALTER TABLE jobs ADD COLUMN speed NUMERIC(3, 2) DEFAULT 1.0;
ALTER TABLE jobs ADD COLUMN pitch NUMERIC(3, 2) DEFAULT 1.0;
ALTER TABLE jobs ADD COLUMN emotion VARCHAR(50) DEFAULT 'neutral';
ALTER TABLE jobs ADD COLUMN language VARCHAR(10) DEFAULT 'en';
ALTER TABLE jobs ADD COLUMN error_message TEXT;
ALTER TABLE jobs ADD COLUMN processing_time_ms INTEGER;

-- Create index to query history logs quickly
CREATE INDEX idx_jobs_user_created ON jobs(user_id, created_at DESC);
```

---

## 3. API Endpoints Design

### A. Synthesize Text (`POST /api/v1/tts/synthesize`)
Submit a new speech generation task.
* **Request Payload**:
  ```json
  {
    "voice_id": "8c59f0f1-4db3-4318-971c-3bbfef1265bf",
    "text": "Welcome to the future of voice cloning technology with ShivaAI.",
    "language": "en",
    "speed": 1.0,
    "pitch": 1.0,
    "emotion": "professional",
    "quality": "high"
  }
  ```
* **Response Payload (HTTP 202 Accepted)**:
  ```json
  {
    "success": true,
    "data": {
      "job_id": "d0e40243-7f2e-4b2a-89a1-5d9c22d1df7b",
      "status": "queued",
      "estimated_wait_seconds": 4.5
    }
  }
  ```

### B. Poll Job Status (`GET /api/v1/tts/jobs/{job_id}`)
Retrieve execution updates of a specific job.
* **Response Payload (HTTP 200 OK - Processing)**:
  ```json
  {
    "success": true,
    "data": {
      "job_id": "d0e40243-7f2e-4b2a-89a1-5d9c22d1df7b",
      "status": "processing",
      "progress": 45
    }
  }
  ```
* **Response Payload (HTTP 200 OK - Completed)**:
  ```json
  {
    "success": true,
    "data": {
      "job_id": "d0e40243-7f2e-4b2a-89a1-5d9c22d1df7b",
      "status": "completed",
      "progress": 100,
      "audio_url": "http://localhost/api/v1/storage/audio/d0e40243.wav",
      "duration_seconds": 4.82,
      "character_count": 62
    }
  }
  ```

---

## 4. Background Queue & Worker Architecture

We segment jobs using isolated Celery queues to prevent fast UI tasks (TTS preview) from getting blocked by long batch runs:

1. **`tts_fast` Queue**: Dedicated to real-time dashboard UI audio previews. Run on GPU instances with minimal batch sizes.
2. **`tts_bulk` Queue**: Handles longer text files, ebooks, or batch exports.
3. **`voice_cloning` Queue**: Dedicated to embedding generation (Module 7).

```
                      FastAPI Route Handler
                               |
            +------------------+------------------+
            | (Short Preview)                     | (Long Text File)
            v                                     v
   Celery [tts_fast] Queue              Celery [tts_bulk] Queue
            |                                     |
            v                                     v
     GPU GPU-Worker-01                     GPU GPU-Worker-02
```

---

## 5. Storage Strategy & Data Retention

* **Storage Engine**: MinIO Bucket `svara-audio`.
* **Path Pattern**: `generations/{user_id}/{year}/{month}/{job_id}.wav`
* **Caching Policy**: Generated audio clips are stored permanently by default for user historical convenience, but users can define auto-expiry policies (e.g. "delete audio after 30 days") to stay compliant with enterprise data protection acts.
