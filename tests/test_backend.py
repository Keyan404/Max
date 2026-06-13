import sys
import os
from fastapi.testclient import TestClient

# Add backend to python path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../backend")))

from app.main import app

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert "docs" in data

def test_list_plugins():
    response = client.get("/api/plugins")
    assert response.status_code == 200
    data = response.json()
    assert "plugins" in data
    plugins = data["plugins"]
    assert len(plugins) >= 2
    assert plugins[0]["plugin_id"] == "weather_skill"

def test_model_determination():
    from app.services.groq_service import GroqService
    service = GroqService()
    
    # Coding prompt should resolve to Qwen Coder
    model = service._determine_model("Write a python script to solve fizzbuzz")
    assert model == "qwen-2.5-coder-32b"
    
    # Reasoning prompt should resolve to DeepSeek R1
    model = service._determine_model("Can you explain why the universe is expanding using general relativity?")
    assert model == "deepseek-r1-distill-llama-70b"
    
    # Default prompt should resolve to Llama 3.3
    model = service._determine_model("Hello, how are you today?")
    assert model == "llama-3.3-70b-versatile"
