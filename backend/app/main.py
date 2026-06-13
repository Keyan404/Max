import os
import json
import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import firebase_admin
from firebase_admin import credentials
from app.core.config import settings
from app.routers import chat, agent, knowledge, plugin

# Configure Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("max_backend")

# Initialize FastAPI App
app = FastAPI(
    title=settings.PROJECT_NAME,
    openapi_url=f"{settings.API_V1_STR}/openapi.json",
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize Firebase Admin SDK
def initialize_firebase():
    cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")
    cred_path = settings.FIREBASE_CREDENTIALS_PATH

    if cred_json:
        try:
            cred_dict = json.loads(cred_json)
            cred = credentials.Certificate(cred_dict)
            firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized successfully from FIREBASE_CREDENTIALS_JSON.")
            return
        except Exception as e:
            logger.error(f"Error initializing Firebase Admin SDK with JSON env var: {e}")

    if cred_path and os.path.exists(cred_path):
        try:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
            logger.info("Firebase Admin SDK initialized successfully from local path.")
        except Exception as e:
            logger.error(f"Error initializing Firebase Admin SDK with key file: {e}")
    else:
        logger.warning(
            "Neither FIREBASE_CREDENTIALS_JSON nor FIREBASE_CREDENTIALS_PATH file found. "
            "Backend will run without Firebase Admin authentication guards."
        )

initialize_firebase()

# Include Routers
app.include_router(chat.router, prefix=settings.API_V1_STR)
app.include_router(agent.router, prefix=settings.API_V1_STR)
app.include_router(knowledge.router, prefix=settings.API_V1_STR)
app.include_router(plugin.router, prefix=settings.API_V1_STR)

@app.get("/")
def read_root():
    return {
        "status": "healthy",
        "project": settings.PROJECT_NAME,
        "docs": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    # Start the server locally
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
