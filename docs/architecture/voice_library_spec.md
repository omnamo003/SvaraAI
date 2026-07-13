# ShivaAI Voice Library Specification
**Module 6**  

---

## 1. System Metadata Model & Voice Versioning

Voice records represent speaker profiles (embeddings). To allow refining custom cloned voices without breaking historical jobs, we support **Voice Versioning**.

```
[Voice Entity] 
  |
  +---> Version 1 (Active)  --> embedding_v1.pth (Inference target)
  |
  +---> Version 2 (Pending) --> embedding_v2.pth (Under training / quality check)
```

Each voice points to an array of structural attributes containing tags, description descriptors, and permission vectors.

---

## 2. Voice Library Database Schema

```sql
-- Core Voice Entity
CREATE TABLE voices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL CHECK (category IN ('system', 'cloned', 'marketplace')),
    owner_id UUID REFERENCES users(id) ON DELETE SET NULL,
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(50) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'verifying')),
    tags VARCHAR(50)[] DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_voices_scope ON voices(organization_id, is_public);

-- Voice Versions containing PyTorch embedding paths
CREATE TABLE voice_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    voice_id UUID NOT NULL REFERENCES voices(id) ON DELETE CASCADE,
    version_number INTEGER NOT NULL,
    embedding_path VARCHAR(512) NOT NULL,  -- MinIO path target
    preview_audio_path VARCHAR(512),       -- Sample audio generation path
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (voice_id, version_number)
);

-- Voice Favorites Mapping
CREATE TABLE voice_favorites (
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    voice_id UUID REFERENCES voices(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, voice_id)
);
```

---

## 3. Storage Strategy & Folder Architecture

Speaker embedding models and audio preview recordings are saved in the MinIO bucket `svara-voices`.

```
/svara-voices
  ├── system/                         # Global pre-made voices
  │     ├── voice_id_1/
  │     │     ├── v1/
  │     │     │     ├── embedding.npy
  │     │     │     └── preview.wav
  ├── organizations/                  # Custom tenant directories
  │     ├── org_id_100/
  │     │     ├── voice_id_502/
  │     │     │     ├── v1/
  │     │     │     │     ├── embedding.npy
  │     │     │     │     └── preview.wav
```

---

## 4. API Design

### A. List Voices (`GET /api/v1/voices`)
Lists available voices, applying organizational scope constraints.
* **Query Parameters**:
  * `category`: Filter by system, cloned, etc.
  * `search`: Matches query word in tag/name vectors.
* **Response Payload (HTTP 200 OK)**:
  ```json
  {
    "success": true,
    "data": [
      {
        "id": "c71e98d9-2cc5-4cf5-9988-51829e1fa122",
        "name": "Sarah - Narrative",
        "description": "Professional calm voice ideal for audiobook reading.",
        "category": "system",
        "tags": ["narrative", "calm", "female"],
        "preview_url": "http://localhost/api/v1/storage/voices/preview_sarah.wav",
        "latest_version": 1
      }
    ]
  }
  ```

### B. Favorite Voice (`POST /api/v1/voices/{id}/favorite`)
Toggle favorite flag.
* **Response Payload (HTTP 200 OK)**:
  ```json
  {
    "success": true,
    "data": {
      "voice_id": "c71e98d9-2cc5-4cf5-9988-51829e1fa122",
      "is_favorited": true
    }
  }
  ```

### C. Share Voice to Team (`POST /api/v1/voices/{id}/share`)
* **Request Payload**:
  ```json
  {
    "target_organization_id": "8c59f0f1-4db3-4318-971c-3bbfef1265bf",
    "access_level": "read-only"
  }
  ```
* **Response Payload (HTTP 200 OK)**:
  ```json
  {
    "success": true,
    "data": {
      "message": "Voice shared successfully with the target workspace."
    }
  }
  ```
