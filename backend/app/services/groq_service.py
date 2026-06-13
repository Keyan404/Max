import json
import logging
from typing import AsyncGenerator, List, Dict, Any, Optional
import httpx
from app.core.config import settings

logger = logging.getLogger("max_backend.groq_service")

class GroqService:
    def __init__(self):
        self.api_key = settings.GROQ_API_KEY
        self.base_url = "https://api.groq.com/openai/v1"
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

    def _determine_model(self, prompt: str, has_image: bool = False, model_override: Optional[str] = None) -> str:
        """
        AI Model Router:
        Selects the best model based on intent and input data.
        """
        if model_override:
            return model_override
        
        if has_image:
            return "llama-3.2-11b-vision-preview"
        
        # Simple heuristic classifier
        prompt_lower = prompt.lower()
        
        # Coding intent detection
        coding_keywords = ["code", "function", "bug", "compile", "class ", "def ", "import ", "html", "css", "javascript", "python", "flutter", "dart", "kotlin", "refactor"]
        is_coding = any(keyword in prompt_lower for keyword in coding_keywords)
        
        # Reasoning intent detection
        reasoning_keywords = ["think", "reason", "prove", "math", "solve", "why ", "logic", "deepseek", "complex"]
        is_reasoning = any(keyword in prompt_lower for keyword in reasoning_keywords)
        
        if is_coding:
            # Qwen Coder
            return "qwen-2.5-coder-32b"
        elif is_reasoning:
            # DeepSeek R1
            return "deepseek-r1-distill-llama-70b"
        else:
            # Llama 3.3 70B
            return "llama-3.3-70b-versatile"

    async def stream_chat(
        self, 
        prompt: str, 
        history: List[Dict[str, str]], 
        context: str = "", 
        model_override: Optional[str] = None
    ) -> AsyncGenerator[str, None]:
        """
        Streams a chat completion using Server-Sent Events (SSE).
        Injects system instructions and RAG context when present.
        """
        if not self.api_key:
            yield "data: " + json.dumps({"error": "GROQ_API_KEY is not configured on the backend."}) + "\n\n"
            return

        model = self._determine_model(prompt, has_image=False, model_override=model_override)
        logger.info(f"Routing query to model: {model}")

        # Construct messages list
        messages = []
        
        # Inject system instructions and memory context
        system_content = (
            "You are MAX, a highly advanced Android AI assistant (\"Your Personal AI Operating System\").\n"
            "You have direct access to system controls on the user's Android device.\n"
            "If the user asks you to perform a system action (like opening an app, calling someone, making a call, toggling flashlight, etc.), you MUST output a special action tag on a new line at the very end of your response:\n"
            "For opening apps: ACTION:launchApp(<package_name>)\n"
            "  - YouTube: com.google.android.youtube\n"
            "  - Settings: com.android.settings\n"
            "  - Camera: com.android.camera\n"
            "  - Browser/Chrome: com.android.chrome\n"
            "For flashlight: ACTION:toggleFlashlight(true/false)\n"
            "For volume: ACTION:controlVolume(up/down)\n"
            "For opening accessibility settings: ACTION:openAccessibilitySettings()\n"
            "For sending automated messages (WhatsApp/SMS): ACTION:scheduleAutomation(<message_text>)\n"
            "For making phone calls: ACTION:callPhone(<phone_number_or_name>)\n"
            "Respond directly, helpfully, and with maximum intelligence.\n"
        )
        if context:
            system_content += f"\nRelevant Memory/Knowledge Base Context:\n{context}\n"
            
        messages.append({"role": "system", "content": system_content})

        # Append conversation history
        for msg in history:
            messages.append({"role": msg["role"], "content": msg["content"]})

        # Append current user prompt
        messages.append({"role": "user", "content": prompt})

        payload = {
            "model": model,
            "messages": messages,
            "stream": True,
            "stream_options": {"include_usage": True}
        }

        async with httpx.AsyncClient(timeout=60.0) as client:
            try:
                async with client.stream(
                    "POST", 
                    f"{self.base_url}/chat/completions", 
                    headers=self.headers, 
                    json=payload
                ) as response:
                    if response.status_code != 200:
                        error_text = await response.aread()
                        logger.error(f"Groq API error: {response.status_code} - {error_text.decode()}")
                        yield "data: " + json.dumps({"error": f"Groq API error: {response.status_code}"}) + "\n\n"
                        return

                    async for line in response.aiter_lines():
                        if not line:
                            continue
                        if line.startswith("data: "):
                            data_str = line[6:]
                            if data_str == "[DONE]":
                                continue
                            try:
                                data_json = json.loads(data_str)
                                # Extract content or usage statistics
                                choices = data_json.get("choices", [])
                                usage = data_json.get("usage", None)
                                
                                if choices:
                                    delta = choices[0].get("delta", {})
                                    content = delta.get("content", "")
                                    # DeepSeek R1 returns reasoning content in reasoning_content field
                                    reasoning_content = delta.get("reasoning_content", "")
                                    
                                    if content or reasoning_content:
                                        yield "data: " + json.dumps({
                                            "content": content,
                                            "reasoning": reasoning_content,
                                            "model": model
                                        }) + "\n\n"
                                        
                                if usage:
                                    # Output token count metrics at the end of stream
                                    yield "data: " + json.dumps({
                                        "usage": usage,
                                        "model": model
                                    }) + "\n\n"
                                    
                            except json.JSONDecodeError:
                                continue
            except Exception as e:
                logger.exception("Exception during chat streaming")
                yield "data: " + json.dumps({"error": f"Backend stream exception: {str(e)}"}) + "\n\n"

    async def analyze_image(self, image_base64: str, prompt: str) -> str:
        """
        Non-streaming vision analysis helper.
        Uses Llama 3.2 11B Vision model.
        """
        if not self.api_key:
            return "GROQ_API_KEY is not configured on the backend."

        model = "llama-3.2-11b-vision-preview"
        
        # Prepare content list
        content = [
            {"type": "text", "text": prompt},
            {
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{image_base64}"
                }
            }
        ]

        payload = {
            "model": model,
            "messages": [
                {
                    "role": "user",
                    "content": content
                }
            ],
            "temperature": 0.2
        }

        async with httpx.AsyncClient(timeout=30.0) as client:
            try:
                response = await client.post(
                    f"{self.base_url}/chat/completions",
                    headers=self.headers,
                    json=payload
                )
                if response.status_code != 200:
                    logger.error(f"Vision API error: {response.status_code} - {response.text}")
                    return f"Vision API error: {response.status_code}"
                
                res_data = response.json()
                return res_data["choices"][0]["message"]["content"]
            except Exception as e:
                logger.exception("Exception during image analysis")
                return f"Backend vision exception: {str(e)}"
