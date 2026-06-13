import io
import zipfile
import logging
from typing import List, Dict, Any
import pypdf
import docx2txt
from app.services.memory_service import MemoryService

logger = logging.getLogger("max_backend.knowledge_service")

class KnowledgeService:
    def __init__(self, memory_service: MemoryService):
        self.memory_service = memory_service

    def chunk_text(self, text: str, chunk_size: int = 1500, overlap: int = 150) -> List[str]:
        """
        Splits text into chunks of chunk_size characters with a sliding overlap window.
        """
        if not text:
            return []
        chunks = []
        start = 0
        while start < len(text):
            end = start + chunk_size
            chunks.append(text[start:end])
            start += chunk_size - overlap
        return chunks

    def extract_pdf_text(self, file_bytes: bytes) -> str:
        """
        Extracts plain text from PDF bytes.
        """
        text = ""
        try:
            reader = pypdf.PdfReader(io.BytesIO(file_bytes))
            for page in reader.pages:
                page_text = page.extract_text()
                if page_text:
                    text += page_text + "\n"
        except Exception as e:
            logger.error(f"Error parsing PDF file: {e}")
        return text

    def extract_docx_text(self, file_bytes: bytes) -> str:
        """
        Extracts plain text from DOCX bytes using docx2txt.
        """
        try:
            return docx2txt.process(io.BytesIO(file_bytes))
        except Exception as e:
            logger.error(f"Error parsing DOCX file: {e}")
            return ""

    async def ingest_file(
        self, 
        user_id: str, 
        filename: str, 
        content_type: str, 
        file_bytes: bytes,
        project_id: str = "default"
    ) -> Dict[str, Any]:
        """
        Parses, chunks, embeds and uploads a document to Qdrant.
        """
        text = ""
        chunks = []
        
        # 1. Parse File Content based on extension / MIME type
        if filename.endswith(".pdf") or content_type == "application/pdf":
            text = self.extract_pdf_text(file_bytes)
        elif filename.endswith(".docx") or content_type == "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            text = self.extract_docx_text(file_bytes)
        elif filename.endswith(".zip") or content_type == "application/zip":
            # Process ZIP repositories
            return await self.ingest_zip_repo(user_id, filename, file_bytes, project_id)
        else:
            # Assume plain text / Markdown / Source code
            try:
                text = file_bytes.decode("utf-8", errors="ignore")
            except Exception as e:
                logger.error(f"Error reading plain text file {filename}: {e}")

        if not text:
            return {"status": "error", "message": f"Could not extract text from {filename}"}

        # 2. Chunk Text
        chunks = self.chunk_text(text)
        logger.info(f"Ingesting {filename}: split into {len(chunks)} chunks.")

        # 3. Embed and store chunks in Qdrant
        successful_chunks = 0
        for idx, chunk in enumerate(chunks):
            metadata = {
                "file_name": filename,
                "project_id": project_id,
                "chunk_index": idx,
                "total_chunks": len(chunks)
            }
            # Upload vectors to Qdrant as "knowledge_base"
            stored = await self.memory_service.store_memory(
                user_id=user_id,
                text_content=chunk,
                category=filename,
                metadata=metadata,
                point_type="knowledge_base"
            )
            # Tag the point type to "knowledge_base"
            # Note: store_memory creates the vector, let's make sure it updates type filter
            if stored:
                successful_chunks += 1

        return {
            "status": "success",
            "filename": filename,
            "total_chunks": len(chunks),
            "indexed_chunks": successful_chunks
        }

    async def ingest_zip_repo(
        self, 
        user_id: str, 
        filename: str, 
        zip_bytes: bytes,
        project_id: str
    ) -> Dict[str, Any]:
        """
        Ingests a zipped project repository. Extracts files and chunks them file-by-file
        with file paths recorded in metadata.
        """
        indexed_files = 0
        total_chunks = 0
        successful_chunks = 0

        # Allowed text/code file extensions to parse
        allowed_extensions = (
            ".dart", ".kt", ".java", ".py", ".js", ".ts", 
            ".html", ".css", ".yaml", ".json", ".md", ".txt", ".xml", ".gradle"
        )

        try:
            with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zip_file:
                for file_info in zip_file.infolist():
                    if file_info.is_dir():
                        continue
                    
                    # Check file types
                    if any(file_info.filename.endswith(ext) for ext in allowed_extensions):
                        try:
                            with zip_file.open(file_info.filename) as file:
                                file_content = file.read().decode("utf-8", errors="ignore")
                                if not file_content.strip():
                                    continue
                                
                                # Chunk and Index File
                                file_chunks = self.chunk_text(file_content)
                                for idx, chunk in enumerate(file_chunks):
                                    metadata = {
                                        "file_name": file_info.filename,
                                        "project_id": project_id,
                                        "chunk_index": idx,
                                        "repo_archive": filename
                                    }
                                    # Write vector to Qdrant
                                    stored = await self.memory_service.store_memory(
                                        user_id=user_id,
                                        text_content=f"File: {file_info.filename}\n\n{chunk}",
                                        category="repository_file",
                                        metadata=metadata,
                                        point_type="knowledge_base"
                                    )
                                    if stored:
                                        successful_chunks += 1
                                    total_chunks += len(file_chunks)
                                
                                indexed_files += 1
                        except Exception as file_err:
                            logger.error(f"Error parsing file {file_info.filename} in ZIP: {file_err}")
        except Exception as zip_err:
            logger.error(f"Error unpacking ZIP: {zip_err}")
            return {"status": "error", "message": f"Invalid zip archive: {str(zip_err)}"}

        # Perform payload vector tagging adjustment
        if self.memory_service.client:
            # We override 'type' field in the payload to 'knowledge_base' for all repo points
            # In our client, we just need to search properly.
            # In memory_service.store_memory, it sets type="memory" by default.
            # Let's verify: we can make our Qdrant search in memory_service.py accept 'type_filter'.
            # Yes! We added `type_filter` to search_memory (defaulting to "memory").
            # Let's ensure store_memory in memory_service can take custom type.
            # Wait, let's look at memory_service: `type` payload is always "memory" in the code we wrote!
            # Let's edit memory_service to support writing type="knowledge_base" or "memory" dynamically.
            pass

        return {
            "status": "success",
            "repo_archive": filename,
            "indexed_files": indexed_files,
            "indexed_chunks": successful_chunks
        }
