import os
from pathlib import Path
from pydantic import BaseModel, Field
from dotenv import load_dotenv

# Load .env file if it exists
env_path = Path(__file__).resolve().parent.parent.parent / ".env"
if env_path.exists():
    load_dotenv(dotenv_path=env_path)
else:
    load_dotenv()

class Settings(BaseModel):
    PROJECT_NAME: str = "MAX AI Assistant Backend"
    API_V1_STR: str = "/api"
    
    # API Keys & Third-party integrations
    GROQ_API_KEY: str = Field(default_factory=lambda: os.getenv("GROQ_API_KEY", ""))
    
    # Firebase configuration
    FIREBASE_CREDENTIALS_PATH: str = Field(default_factory=lambda: os.getenv("FIREBASE_CREDENTIALS_PATH", ""))
    
    # Qdrant Vector DB
    QDRANT_HOST: str = Field(default_factory=lambda: os.getenv("QDRANT_HOST", "localhost"))
    QDRANT_PORT: int = Field(default_factory=lambda: int(os.getenv("QDRANT_PORT", "6333")))
    QDRANT_API_KEY: str = Field(default_factory=lambda: os.getenv("QDRANT_API_KEY", ""))
    
    # Security
    JWT_SECRET: str = Field(default_factory=lambda: os.getenv("JWT_SECRET", "super_secret_max_key_13579"))
    ALGORITHM: str = "HS256"
    
    # Search API (fallback to local duckduckgo crawler if no key)
    SERPER_API_KEY: str = Field(default_factory=lambda: os.getenv("SERPER_API_KEY", ""))

    class Config:
        case_sensitive = True

settings = Settings()
