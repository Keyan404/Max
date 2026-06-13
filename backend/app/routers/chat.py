import json
import logging
from typing import List, Dict, Any, Optional
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
from app.services.groq_service import GroqService
from app.services.memory_service import MemoryService

logger = logging.getLogger("max_backend.routers.chat")
router = APIRouter(prefix="/chat", tags=["chat"])

# Dependency Providers
def get_groq_service() -> GroqService:
    return GroqService()

def get_memory_service() -> MemoryService:
    return MemoryService()

class Message(BaseModel):
    role: str  # "user" or "assistant"
    content: str

class ChatRequest(BaseModel):
    user_id: str
    prompt: str
    history: List[Message] = []
    project_id: Optional[str] = "default"
    model_override: Optional[str] = None
    use_rag: Optional[bool] = True

class VisionRequest(BaseModel):
    image_base64: str
    prompt: str

@router.post("/stream")
async def stream_chat(
    req: ChatRequest,
    groq: GroqService = Depends(get_groq_service),
    memory: MemoryService = Depends(get_memory_service)
):
    """
    Streams conversational response. Retrieves vector memories from Qdrant if use_rag is True.
    """
    context_str = ""
    
    if req.use_rag:
        try:
            # 1. Fetch relevant memories & knowledge base articles
            memories = await memory.search_memory(user_id=req.user_id, query=req.prompt, limit=3, type_filter="memory")
            kb_docs = await memory.search_memory(user_id=req.user_id, query=req.prompt, limit=3, type_filter="knowledge_base")
            
            context_items = []
            if memories:
                context_items.append("=== USER PERSONAL MEMORY ===")
                for m in memories:
                    context_items.append(f"- {m['text']}")
            if kb_docs:
                context_items.append("=== RELEVANT KNOWLEDGE BASE DOCS ===")
                for d in kb_docs:
                    context_items.append(f"- {d['text']}")
            
            if context_items:
                context_str = "\n".join(context_items)
                logger.info(f"RAG Context compiled: {len(context_str)} characters.")
        except Exception as e:
            logger.warning(f"Error fetching RAG context: {e}")

    # Convert Pydantic model array to dictionary format
    history_dicts = [{"role": msg.role, "content": msg.content} for msg in req.history]

    # Return streamed response
    async def event_generator():
        async for chunk in groq.stream_chat(
            prompt=req.prompt,
            history=history_dicts,
            context=context_str,
            model_override=req.model_override
        ):
            yield chunk

    return StreamingResponse(event_generator(), media_type="text/event-stream")

@router.post("/vision")
async def analyze_screen(
    req: VisionRequest,
    groq: GroqService = Depends(get_groq_service)
):
    """
    Processes screenshots / image streams using Llama 3.2 Vision.
    """
    if not req.image_base64:
        raise HTTPException(status_code=400, detail="Missing base64 image data.")
        
    analysis_result = await groq.analyze_image(
        image_base64=req.image_base64,
        prompt=req.prompt
    )
    return {"analysis": analysis_result}
