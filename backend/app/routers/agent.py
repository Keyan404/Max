import uuid
import logging
from typing import Dict, Any, Optional
from pydantic import BaseModel
from fastapi import APIRouter, Depends, BackgroundTasks, HTTPException
from app.services.agent_service import AgentService

logger = logging.getLogger("max_backend.routers.agent")
router = APIRouter(prefix="/agent", tags=["agent"])

# Thread-safe Singleton Dependency
_agent_service_instance = AgentService()

def get_agent_service() -> AgentService:
    return _agent_service_instance

class AgentRunRequest(BaseModel):
    prompt: str
    task_id: Optional[str] = None

@router.post("/run")
async def run_agent_task(
    req: AgentRunRequest,
    background_tasks: BackgroundTasks,
    agent: AgentService = Depends(get_agent_service)
):
    """
    Triggers an asynchronous multi-step reasoning agent task.
    Returns a task ID immediately.
    """
    task_id = req.task_id or str(uuid.uuid4())
    logger.info(f"Scheduling agent task {task_id}: {req.prompt}")
    
    # Run the agent in the background
    background_tasks.add_task(
        agent.execute_task,
        task_id=task_id,
        prompt=req.prompt
    )
    
    return {
        "status": "scheduled",
        "task_id": task_id
    }

@router.get("/trace/{task_id}")
async def get_agent_trace(
    task_id: str,
    agent: AgentService = Depends(get_agent_service)
):
    """
    Retrieves the execution trace history (thoughts, actions, observations) for Developer Mode.
    """
    trace = agent.get_trace(task_id)
    if not trace:
        # Check if the task exists or has started
        return {"status": "not_found_or_pending", "trace": []}
        
    return {
        "status": "active",
        "task_id": task_id,
        "trace": trace
    }
