import logging
from typing import Optional
from fastapi import APIRouter, Depends, UploadFile, File, Form, HTTPException
from app.services.memory_service import MemoryService
from app.services.knowledge_service import KnowledgeService

logger = logging.getLogger("max_backend.routers.knowledge")
router = APIRouter(prefix="/knowledge", tags=["knowledge"])

def get_memory_service() -> MemoryService:
    return MemoryService()

def get_knowledge_service(memory: MemoryService = Depends(get_memory_service)) -> KnowledgeService:
    return KnowledgeService(memory_service=memory)

@router.post("/upload")
async def upload_document(
    user_id: str = Form(...),
    project_id: Optional[str] = Form("default"),
    file: UploadFile = File(...),
    service: KnowledgeService = Depends(get_knowledge_service)
):
    """
    Accepts document uploads (PDF, DOCX, ZIP repo, TXT, MD) and chunk-indexes them.
    """
    try:
        file_bytes = await file.read()
        if not file_bytes:
            raise HTTPException(status_code=400, detail="Uploaded file is empty.")
            
        result = await service.ingest_file(
            user_id=user_id,
            filename=file.filename,
            content_type=file.content_type,
            file_bytes=file_bytes,
            project_id=project_id
        )
        
        if result.get("status") == "error":
            raise HTTPException(status_code=500, detail=result.get("message"))
            
        return result
    except Exception as e:
        logger.exception("Error uploading and indexing document")
        raise HTTPException(status_code=500, detail=f"Ingestion failed: {str(e)}")

@router.get("/search")
async def search_knowledge(
    user_id: str,
    query: str,
    limit: Optional[int] = 5,
    memory: MemoryService = Depends(get_memory_service)
):
    """
    Queries indexed documents using vector semantic search.
    """
    try:
        results = await memory.search_memory(
            user_id=user_id,
            query=query,
            limit=limit,
            type_filter="knowledge_base"
        )
        return {"results": results}
    except Exception as e:
        logger.exception("Error searching knowledge base")
        raise HTTPException(status_code=500, detail=f"Search failed: {str(e)}")
