from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="Svara AI Gateway",
    description="Orchestrator and API Gateway for the Svara AI Voice Platform",
    version="0.1.0",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify actual domain(s)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {
        "status": "healthy",
        "service": "Svara AI Backend Gateway",
        "version": "0.1.0"
    }

@app.get("/health")
async def health_check():
    # Basic health check endpoint
    return {"status": "ok"}
