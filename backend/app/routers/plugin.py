import logging
from typing import Dict, List, Any, Optional
from pydantic import BaseModel
from fastapi import APIRouter, HTTPException

logger = logging.getLogger("max_backend.routers.plugin")
router = APIRouter(prefix="/plugins", tags=["plugins"])

class PluginParameter(BaseModel):
    name: str
    type: str  # "string" | "integer" | "boolean"
    required: bool
    description: str

class PluginEndpoint(BaseModel):
    path: str
    method: str  # "GET" | "POST"
    description: str
    parameters: List[PluginParameter] = []

class PluginRegisterRequest(BaseModel):
    plugin_id: str
    name: str
    description: str
    required_permissions: List[str] = []
    endpoints: Dict[str, PluginEndpoint]
    enabled: Optional[bool] = True

# Thread-safe in-memory Registry (In production this registers and syncs to Firestore)
_plugin_registry: Dict[str, Dict[str, Any]] = {
    "weather_skill": {
        "plugin_id": "weather_skill",
        "name": "Live Weather updates",
        "description": "Provides real-time local weather forecasts.",
        "required_permissions": ["LOCATION"],
        "enabled": True,
        "endpoints": {
            "get_weather": {
                "path": "/plugins/weather/current",
                "method": "GET",
                "description": "Gets current weather based on coordinates.",
                "parameters": [
                    {"name": "lat", "type": "string", "required": True, "description": "Latitude"},
                    {"name": "lon", "type": "string", "required": True, "description": "Longitude"}
                ]
            }
        }
    },
    "sms_skill": {
        "plugin_id": "sms_skill",
        "name": "SMS Messaging automation",
        "description": "Enables sending SMS messages through Accessibility Service automation.",
        "required_permissions": ["SMS", "ACCESSIBILITY"],
        "enabled": True,
        "endpoints": {
            "send_sms": {
                "path": "/plugins/sms/send",
                "method": "POST",
                "description": "Automates sending an SMS message.",
                "parameters": [
                    {"name": "phone", "type": "string", "required": True, "description": "Target phone number"},
                    {"name": "message", "type": "string", "required": True, "description": "Message content"}
                ]
            }
        }
    }
}

@router.get("")
async def list_plugins():
    """
    Lists all registered plugins and their permission requirements.
    """
    return {"plugins": list(_plugin_registry.values())}

@router.post("/register")
async def register_plugin(req: PluginRegisterRequest):
    """
    Dynamically registers a new skill plugin.
    """
    if req.plugin_id in _plugin_registry:
        logger.info(f"Updating plugin registry for {req.plugin_id}")
    else:
        logger.info(f"Registering new plugin: {req.plugin_id}")
        
    _plugin_registry[req.plugin_id] = req.dict()
    return {"status": "registered", "plugin_id": req.plugin_id}

@router.put("/{plugin_id}/toggle")
async def toggle_plugin(plugin_id: str, enabled: bool):
    """
    Enables/disables a specific plugin.
    """
    if plugin_id not in _plugin_registry:
        raise HTTPException(status_code=404, detail=f"Plugin {plugin_id} not found.")
        
    _plugin_registry[plugin_id]["enabled"] = enabled
    logger.info(f"Plugin {plugin_id} toggle status set to: {enabled}")
    return {"status": "updated", "plugin_id": plugin_id, "enabled": enabled}
