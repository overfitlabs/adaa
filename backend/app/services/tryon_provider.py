import abc
import asyncio
from pathlib import Path
from typing import Dict, Any, Optional
import httpx
from app.config import settings


class VirtualTryOnProvider(abc.ABC):
    @abc.abstractmethod
    async def create_tryon_task(
        self, user_image_path: Path, garment_image_path: Path, garment_category: str = "upper body"
    ) -> Dict[str, Any]:
        """
        Creates an asynchronous virtual try-on task.
        Returns: {"task_id": str, "status": str, "provider": str}
        """
        pass

    @abc.abstractmethod
    async def get_task_status(self, task_id: str) -> Dict[str, Any]:
        """
        Polls the status of an ongoing try-on task.
        Returns: {"task_id": str, "status": str, "result_url": Optional[str], "error": Optional[str]}
        """
        pass


class YouCamTryOnProvider(VirtualTryOnProvider):
    """
    Official YouCam / Perfect Corp S2S Virtual Try-On integration.
    Endpoints:
    - POST /file : upload source assets
    - POST /task/clothes-vto : initialize generative try-on task
    - GET  /task/{task_id} : query task status and retrieve resulting composite
    """

    def __init__(self, api_key: str, base_url: str):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Accept": "application/json",
        }

    async def _upload_file(self, file_path: Path, client: httpx.AsyncClient) -> str:
        """Uploads local image asset to YouCam file endpoint."""
        url = f"{self.base_url}/file"
        with open(file_path, "rb") as f:
            files = {"file": (file_path.name, f.read(), "image/jpeg")}
            resp = await client.post(url, headers={"Authorization": f"Bearer {self.api_key}"}, files=files, timeout=30.0)
            resp.raise_for_status()
            data = resp.json()
            # File response usually returns file_id or download_url
            return data.get("file_id") or data.get("url") or data.get("data", {}).get("file_id")

    async def create_tryon_task(
        self, user_image_path: Path, garment_image_path: Path, garment_category: str = "upper body"
    ) -> Dict[str, Any]:
        if not self.api_key:
            raise ValueError("YouCam API Key is required to call YouCamTryOnProvider.")

        async with httpx.AsyncClient() as client:
            # 1. Upload user image
            user_file_ref = await self._upload_file(user_image_path, client)
            # 2. Upload garment image
            garment_file_ref = await self._upload_file(garment_image_path, client)

            # 3. Create task
            task_url = f"{self.base_url}/task/clothes-vto"
            payload = {
                "user_image": user_file_ref,
                "garment_image": garment_file_ref,
                "garment_category": garment_category,
            }
            resp = await client.post(task_url, headers=self.headers, json=payload, timeout=30.0)
            resp.raise_for_status()
            result = resp.json()
            task_id = result.get("task_id") or result.get("data", {}).get("task_id")

            return {
                "task_id": task_id,
                "status": "processing",
                "provider": "youcam",
            }

    async def get_task_status(self, task_id: str) -> Dict[str, Any]:
        if not self.api_key:
            raise ValueError("YouCam API Key is required.")

        url = f"{self.base_url}/task/{task_id}"
        async with httpx.AsyncClient() as client:
            resp = await client.get(url, headers=self.headers, timeout=20.0)
            resp.raise_for_status()
            data = resp.json()

            # Status schema handling
            status = data.get("status", "unknown").lower()
            # YouCam typically uses: 'running' / 'in_progress' / 'success' / 'failed'
            if status in ["running", "in_progress", "pending"]:
                norm_status = "processing"
            elif status in ["success", "completed", "done"]:
                norm_status = "success"
            else:
                norm_status = "failed"

            result_url = (
                data.get("result_url")
                or data.get("data", {}).get("result_url")
                or data.get("data", {}).get("url")
            )
            error_msg = data.get("error") or data.get("message")

            return {
                "task_id": task_id,
                "status": norm_status,
                "result_url": result_url,
                "error": error_msg,
                "provider": "youcam",
            }


class MockTryOnProvider(VirtualTryOnProvider):
    """
    Predictable mock provider for tests and safe offline development.
    Simulates asynchronous task lifecycle (pending -> processing -> success).
    """

    _task_db: Dict[str, Dict[str, Any]] = {}

    async def create_tryon_task(
        self, user_image_path: Path, garment_image_path: Path, garment_category: str = "upper body"
    ) -> Dict[str, Any]:
        import uuid
        task_id = f"mock-tryon-{uuid.uuid4().hex[:10]}"
        self._task_db[task_id] = {
            "poll_count": 0,
            "status": "processing",
            "user_image_path": str(user_image_path),
            "garment_image_path": str(garment_image_path),
            "garment_category": garment_category,
        }
        return {
            "task_id": task_id,
            "status": "processing",
            "provider": "mock",
        }

    async def get_task_status(self, task_id: str) -> Dict[str, Any]:
        task = self._task_db.get(task_id)
        if not task:
            return {
                "task_id": task_id,
                "status": "failed",
                "result_url": None,
                "error": "Task not found in mock store",
                "provider": "mock",
            }

        task["poll_count"] += 1
        # Succeed after 2 polls to simulate real async processing latency
        if task["poll_count"] >= 2:
            task["status"] = "success"
            return {
                "task_id": task_id,
                "status": "success",
                # Returns high-res try-on placeholder visualization
                "result_url": "https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?auto=format&fit=crop&w=800&q=80",
                "error": None,
                "provider": "mock",
            }

        return {
            "task_id": task_id,
            "status": "processing",
            "result_url": None,
            "error": None,
            "provider": "mock",
        }


def get_tryon_provider() -> VirtualTryOnProvider:
    if settings.TRYON_PROVIDER.lower() == "youcam" and settings.YOUCAM_API_KEY:
        return YouCamTryOnProvider(
            api_key=settings.YOUCAM_API_KEY,
            base_url=settings.YOUCAM_BASE_URL,
        )
    return MockTryOnProvider()
