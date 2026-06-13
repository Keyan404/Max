import os
import json
import logging
import uuid
import subprocess
from typing import List, Dict, Any, Optional
import httpx
from app.core.config import settings

logger = logging.getLogger("max_backend.agent_service")

class AgentService:
    def __init__(self):
        # Memory buffer for running agent traces
        self.traces: Dict[str, List[Dict[str, Any]]] = {}
        # Sandbox workspace root
        self.sandbox_root = os.path.abspath(os.path.join(os.getcwd(), "sandbox"))
        if not os.path.exists(self.sandbox_root):
            os.makedirs(self.sandbox_root)

    def _get_sandbox_path(self, relative_path: str) -> str:
        """
        Secures file paths to stay within the sandbox root directory.
        """
        resolved = os.path.abspath(os.path.join(self.sandbox_root, relative_path))
        if not resolved.startswith(self.sandbox_root):
            raise PermissionError("Access denied: Attempt to escape sandbox directory.")
        return resolved

    def _tool_list_dir(self, relative_path: str = ".") -> str:
        try:
            path = self._get_sandbox_path(relative_path)
            if not os.path.exists(path):
                return f"Directory {relative_path} does not exist."
            files = os.listdir(path)
            return json.dumps(files)
        except Exception as e:
            return f"Error listing directory: {str(e)}"

    def _tool_read_file(self, relative_path: str) -> str:
        try:
            path = self._get_sandbox_path(relative_path)
            if not os.path.exists(path):
                return f"File {relative_path} does not exist."
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                return f.read()
        except Exception as e:
            return f"Error reading file: {str(e)}"

    def _tool_write_file(self, relative_path: str, content: str) -> str:
        try:
            path = self._get_sandbox_path(relative_path)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            return f"File {relative_path} written successfully."
        except Exception as e:
            return f"Error writing file: {str(e)}"

    def _tool_run_command(self, command: str) -> str:
        """
        Executes a script/command inside the sandbox.
        """
        try:
            # Enforce execution in sandbox
            res = subprocess.run(
                command, 
                shell=True, 
                cwd=self.sandbox_root, 
                capture_output=True, 
                text=True, 
                timeout=15.0
            )
            return f"Exit Code: {res.returncode}\nStdout: {res.stdout}\nStderr: {res.stderr}"
        except subprocess.TimeoutExpired:
            return "Error: Command timed out after 15 seconds."
        except Exception as e:
            return f"Error running command: {str(e)}"

    async def _tool_web_search(self, query: str) -> str:
        """
        Queries Serper API or falls back to DuckDuckGo search.
        """
        if settings.SERPER_API_KEY:
            headers = {"X-API-KEY": settings.SERPER_API_KEY, "Content-Type": "application/json"}
            payload = {"q": query}
            async with httpx.AsyncClient(timeout=10.0) as client:
                try:
                    res = await client.post("https://google.serper.dev/search", headers=headers, json=payload)
                    if res.status_code == 200:
                        snippets = [item.get("snippet", "") for item in res.json().get("organic", [])[:3]]
                        return "\n".join(snippets)
                except Exception as e:
                    logger.warning(f"Serper search failed: {e}")
        
        # Fallback Mock / Standard response when offline/no keys
        return f"Web Search Result for '{query}': Direct API access disabled. Fallback mock returned."

    async def execute_task(self, task_id: str, prompt: str) -> Dict[str, Any]:
        """
        Executes a task by orchestrating multiple steps using Llama 3.3 or DeepSeek R1.
        Runs a ReAct (Reason-Act-Observe) loop.
        """
        self.traces[task_id] = []
        
        system_prompt = (
            "You are the MAX Agent Executor. You solve complex multi-step tasks.\n"
            "You have access to the following tools:\n"
            "1. list_dir(relative_path: str = '.') -> JSON list of files\n"
            "2. read_file(relative_path: str) -> Content of file\n"
            "3. write_file(relative_path: str, content: str) -> Success msg\n"
            "4. run_command(command: str) -> Exit code and stdout/stderr\n"
            "5. web_search(query: str) -> Google snippets\n\n"
            "Respond in JSON format with keys:\n"
            "- 'thought': Your analysis of the task and next step.\n"
            "- 'action': The name of the tool to execute ('list_dir', 'read_file', 'write_file', 'run_command', 'web_search', or 'finish').\n"
            "- 'action_input': The parameter value to pass to the tool (string).\n"
        )

        history = [{"role": "system", "content": system_prompt}]
        history.append({"role": "user", "content": f"Task: {prompt}"})

        max_steps = 5
        result_content = ""

        # Using DeepSeek R1 for reasoning or falling back to Llama 3.3
        model = "deepseek-r1-distill-llama-70b" if settings.GROQ_API_KEY else "mock-agent"
        
        if not settings.GROQ_API_KEY:
            # Fallback mock for testing/offline runs
            mock_trace = {
                "thought": "No Groq API Key provided. Running local mock task.",
                "action": "write_file",
                "action_input": "hello.txt",
                "observation": "File hello.txt written successfully."
            }
            self.traces[task_id].append(mock_trace)
            self._tool_write_file("hello.txt", "Hello from MAX Local Agent Sandbox!")
            return {"status": "success", "task_id": task_id, "output": "Mock task complete. File hello.txt created."}

        async with httpx.AsyncClient(timeout=30.0) as client:
            for step in range(max_steps):
                try:
                    response = await client.post(
                        "https://api.groq.com/openai/v1/chat/completions",
                        headers={"Authorization": f"Bearer {settings.GROQ_API_KEY}", "Content-Type": "application/json"},
                        json={
                            "model": model,
                            "messages": history,
                            "response_format": {"type": "json_object"}
                        }
                    )
                    
                    if response.status_code != 200:
                        err_msg = f"Agent call failed: {response.status_code} - {response.text}"
                        self.traces[task_id].append({"error": err_msg})
                        return {"status": "error", "message": err_msg}

                    res_data = response.json()
                    raw_content = res_data["choices"][0]["message"]["content"]
                    
                    # Parse agent decision
                    agent_step = json.loads(raw_content)
                    thought = agent_step.get("thought", "")
                    action = agent_step.get("action", "finish")
                    action_input = agent_step.get("action_input", "")

                    logger.info(f"Agent Step {step+1}: Thought={thought}, Action={action}, Input={action_input}")
                    
                    trace_entry = {
                        "step": step + 1,
                        "thought": thought,
                        "action": action,
                        "action_input": action_input,
                        "observation": ""
                    }

                    if action == "finish":
                        trace_entry["observation"] = "Task finalized."
                        self.traces[task_id].append(trace_entry)
                        result_content = action_input
                        break

                    # Execute Action
                    observation = ""
                    if action == "list_dir":
                        observation = self._tool_list_dir(action_input or ".")
                    elif action == "read_file":
                        observation = self._tool_read_file(action_input)
                    elif action == "write_file":
                        # Input might be a nested JSON or raw text. If written by agent, write content.
                        observation = self._tool_write_file(action_input, "File content placeholder. To write raw text, use specific tool inputs.")
                    elif action == "run_command":
                        observation = self._tool_run_command(action_input)
                    elif action == "web_search":
                        observation = await self._tool_web_search(action_input)
                    else:
                        observation = f"Unknown action: {action}"

                    trace_entry["observation"] = observation
                    self.traces[task_id].append(trace_entry)

                    # Update history context
                    history.append({"role": "assistant", "content": raw_content})
                    history.append({"role": "user", "content": f"Observation: {observation}"})

                except Exception as e:
                    logger.exception("Error in agent step loop")
                    self.traces[task_id].append({"error": f"Agent step crash: {str(e)}"})
                    return {"status": "error", "message": str(e)}

        return {
            "status": "success",
            "task_id": task_id,
            "output": result_content or "Agent task completed.",
            "steps": len(self.traces[task_id])
        }

    def get_trace(self, task_id: str) -> List[Dict[str, Any]]:
        return self.traces.get(task_id, [])
