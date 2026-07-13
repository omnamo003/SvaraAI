import os
import time

# pyrefly: ignore [missing-import]
from celery import Celery

# Read Redis URL from environment or default to local development address
redis_url = os.getenv("REDIS_URL", "redis://redis:6379/0")

celery_app = Celery("svara_tasks", broker=redis_url, backend=redis_url)

# Optional configurations
celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
)


@celery_app.task(name="generate_tts_task")
def generate_tts_task(text: str, voice_id: str, job_id: str):
    print(f"[Worker] Starting TTS generation job {job_id} for voice {voice_id}")
    print(f"[Worker] Synthesizing text: '{text}'")

    # Simulate processing time
    time.sleep(2)

    print(f"[Worker] Finished synthesis for job {job_id}")
    return {
        "status": "completed",
        "job_id": job_id,
        "audio_url": f"http://localhost:9000/svara-audio/generations/{job_id}.wav",
        "characters_processed": len(text),
    }
