import logging
from typing import List, Dict, Any, Optional
import httpx
from qdrant_client import QdrantClient
from qdrant_client.http import models
from app.core.config import settings

logger = logging.getLogger("max_backend.memory_service")

class MemoryService:
    def __init__(self):
        self.qdrant_host = settings.QDRANT_HOST
        self.qdrant_port = settings.QDRANT_PORT
        self.qdrant_api_key = settings.QDRANT_API_KEY
        self.collection_name = "max_embeddings"
        self.embedding_model = "nomic-embed-text-v1.5"
        self.client = None
        self._initialize_qdrant()

    def _initialize_qdrant(self):
        """
        Initializes the Qdrant client and verifies/creates the collections.
        Gracefully handles exceptions if Qdrant is offline.
        """
        try:
            if self.qdrant_api_key:
                # Connected to Qdrant Cloud
                self.client = QdrantClient(
                    url=f"https://{self.qdrant_host}",
                    api_key=self.qdrant_api_key,
                    timeout=5.0
                )
            else:
                # Connected locally
                self.client = QdrantClient(
                    host=self.qdrant_host,
                    port=self.qdrant_port,
                    timeout=5.0
                )
            
            # Create collection if it doesn't exist (768 dimensions for nomic-embed-text-v1.5)
            collections_res = self.client.get_collections()
            existing = [col.name for col in collections_res.collections]
            
            if self.collection_name not in existing:
                self.client.create_collection(
                    collection_name=self.collection_name,
                    vectors_config=models.VectorParams(
                        size=768, 
                        distance=models.Distance.COSINE
                    )
                )
                logger.info(f"Created Qdrant collection: {self.collection_name}")
        except Exception as e:
            logger.warning(f"Could not connect to Qdrant Vector DB: {e}. Running in memory fallback mode.")
            self.client = None

    async def get_embedding(self, text: str) -> Optional[List[float]]:
        """
        Calls Groq's embedding API to generate a vector representation of text.
        """
        if not settings.GROQ_API_KEY:
            logger.error("GROQ_API_KEY not configured. Cannot generate embeddings.")
            return None

        url = "https://api.groq.com/openai/v1/embeddings"
        headers = {
            "Authorization": f"Bearer {settings.GROQ_API_KEY}",
            "Content-Type": "application/json"
        }
        payload = {
            "input": text,
            "model": self.embedding_model
        }

        async with httpx.AsyncClient(timeout=10.0) as client:
            try:
                response = await client.post(url, headers=headers, json=payload)
                if response.status_code != 200:
                    logger.error(f"Groq Embedding API error: {response.status_code} - {response.text}")
                    return None
                
                result = response.json()
                return result["data"][0]["embedding"]
            except Exception as e:
                logger.error(f"Failed to generate embedding: {e}")
                return None

    async def store_memory(
        self, 
        user_id: str, 
        text_content: str, 
        category: str, 
        metadata: Optional[Dict[str, Any]] = None,
        point_type: str = "memory"
    ) -> bool:
        """
        Generates embedding and stores payload inside Qdrant.
        """
        if not self.client:
            logger.warning("Qdrant client unavailable. Skipping vector storage.")
            return False

        embedding = await self.get_embedding(text_content)
        if not embedding:
            return False

        point_id = hash(f"{user_id}_{text_content}_{category}") % (10 ** 10)
        
        payload = {
            "user_id": user_id,
            "type": point_type,
            "category": category,
            "text_content": text_content,
            "metadata": metadata or {}
        }

        try:
            self.client.upsert(
                collection_name=self.collection_name,
                points=[
                    models.PointStruct(
                        id=point_id,
                        vector=embedding,
                        payload=payload
                    )
                ]
            )
            return True
        except Exception as e:
            logger.error(f"Failed to upsert memory point to Qdrant: {e}")
            return False

    async def search_memory(
        self, 
        user_id: str, 
        query: str, 
        limit: int = 5,
        type_filter: str = "memory"
    ) -> List[Dict[str, Any]]:
        """
        Performs semantic vector search in Qdrant filtering by user_id and payload type.
        """
        if not self.client:
            logger.warning("Qdrant client unavailable. Skipping search.")
            return []

        embedding = await self.get_embedding(query)
        if not embedding:
            return []

        # Filter by user_id and document type
        query_filter = models.Filter(
            must=[
                models.FieldCondition(
                    key="user_id",
                    match=models.MatchValue(value=user_id)
                ),
                models.FieldCondition(
                    key="type",
                    match=models.MatchValue(value=type_filter)
                )
            ]
        )

        try:
            search_results = self.client.search(
                collection_name=self.collection_name,
                query_vector=embedding,
                query_filter=query_filter,
                limit=limit
            )
            
            memories = []
            for hit in search_results:
                memories.append({
                    "text": hit.payload.get("text_content"),
                    "category": hit.payload.get("category"),
                    "metadata": hit.payload.get("metadata", {}),
                    "score": hit.score
                })
            return memories
        except Exception as e:
            logger.error(f"Failed to query Qdrant: {e}")
            return []
