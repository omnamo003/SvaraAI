# ShivaAI Voice Cloning Pipeline Specification
**Module 7**  

---

## 1. Voice Cloning Pipeline Workflow

To protect privacy and ensure high synthesis output, the cloning sequence flows through a series of validation, processing, and generation stages:

```
[Raw Audio Upload] + [Recorded Consent Text]
       |
       v
[Consent Evaluator] (Validate user is reading the official consent statement)
       |
       v (Success)
[Audio Quality Gate] (SNR evaluation, peak checks, normalization)
       |
       v (Pass)
[Celery Queue: cloning] (Dispatches to GPU worker)
       |
       v
[Worker processing]
  1. Noise Removal (Demucs / Librosa gate)
  2. Normalize (RMS target -20dB)
  3. Speaker Embedding Extraction (Encoder Model)
       |
       v
[Validate Embedding] (Compare generated voice similarity score)
       |
       v (Approved)
[Publish Voice Profile] (Save embedding to svara-voices storage bucket)
```

---

## 2. Consent & Verification Model

ShivaAI enforces strict ethical AI rules. 
* Developers must upload a recording of the target speaker reading a dynamic verification script: *"I, [Speaker Name], authorize ShivaAI to clone my voice and synthesize speech outputs."*
* The FastAPI gateway routes this recording to a **Speaker Verification Model** which checks:
  1. **Text Transcription Matching**: Audio text must align 100% with the authorization script.
  2. **Speaker Verification**: The speaker identity matching score against the actual sample files must exceed a confidence threshold of **95%**.

---

## 3. Database Schemas

```sql
-- Extend Voices table for verification tracing
ALTER TABLE voices ADD COLUMN consent_verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE voices ADD COLUMN verification_job_id UUID;
ALTER TABLE voices ADD COLUMN confidence_score NUMERIC(5, 4);

-- Voice Cloning Job State Table
CREATE TABLE voice_cloning_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voice_id UUID NOT NULL REFERENCES voices(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'queued' CHECK (status IN ('queued', 'processing', 'quality_check_failed', 'consent_failed', 'completed', 'failed')),
    noise_level_db NUMERIC(5, 2),
    clipping_ratio NUMERIC(5, 4),
    error_message TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_clone_jobs_voice ON voice_cloning_jobs(voice_id);
```

---

## 4. API Design

### A. Initialize Voice Clone (`POST /api/v1/clones`)
Upload training sample files.
* **Multipart Form Request**:
  * `name`: string
  * `samples`: File arrays (minimum 3 samples, WAV/MP3 formats, max 10MB each)
  * `consent_audio`: Verification recording file
* **Response Payload (HTTP 202 Accepted)**:
  ```json
  {
    "success": true,
    "data": {
      "voice_id": "9d901844-3bc1-44ee-b9cc-81829ea1fa22",
      "cloning_job_id": "1bc2f850-0f66-45aa-a851-0df7f815e679",
      "status": "processing"
    }
  }
  ```

### B. Fetch Clone Status (`GET /api/v1/clones/jobs/{id}`)
* **Response Payload (HTTP 200 OK - Quality Failed)**:
  ```json
  {
    "success": false,
    "error": {
      "code": "QUALITY_CHECK_FAILED",
      "message": "The uploaded audio samples failed the signal-to-noise ratio check.",
      "details": {
        "snr_db": 12.4,
        "min_required_snr_db": 20.0
      }
    }
  }
  ```

---

## 5. GPU Worker & Abstraction Strategy

For extracting speaker embeddings, we use Celery running on a GPU queue. The cloner logic is abstracted to support switching embedding models (e.g. ECAPA-TDNN, d-vector, or proprietary encoders):

```python
class VoiceEncoder(ABC):
    @abstractmethod
    def extract_embedding(self, audio_paths: list[str]) -> bytes:
        """Extract a fixed-size speaker identity embedding array."""
        pass
```

### Future Model Replacement Roadmap
1. Phase 1 (Current): **Open-source encoders** (Coqui XTTS v2 speaker reference / PyAnnote embedding model).
2. Phase 2 (Future): **Proprietary ShivaAI Encoder** (yielding a custom 512-dimension vector specifically trained on multi-lingual datasets).
The transition requires only implementing the `VoiceEncoder` interface. No changes are required in the pipeline orchestrator, consent validation, or storage modules.
