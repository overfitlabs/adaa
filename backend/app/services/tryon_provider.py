import abc
import asyncio
import logging
from typing import Dict, Any, Optional
import httpx
from app.config import settings

logger = logging.getLogger("wardrobelens.tryon_provider")

VALID_GARMENT_CATEGORIES = {
    "upper body",
    "upper_body",
    "lower body",
    "lower_body",
    "full body",
    "full_body",
    "dress",
    "outer",
    "shoes",
    "auto",
}

# Category normalization mapping to YouCam-supported parameters
YOUCAM_CATEGORY_MAP = {
    "upper body": "upper_body",
    "upper_body": "upper_body",
    "top": "upper_body",
    "tops": "upper_body",
    "shirt": "upper_body",
    "shirts": "upper_body",
    "t-shirt": "upper_body",
    "t-shirts": "upper_body",
    "blouse": "upper_body",
    "sweater": "upper_body",
    "hoodie": "upper_body",
    "lower body": "lower_body",
    "lower_body": "lower_body",
    "bottom": "lower_body",
    "bottoms": "lower_body",
    "pants": "lower_body",
    "trousers": "lower_body",
    "jeans": "lower_body",
    "shorts": "lower_body",
    "skirt": "lower_body",
    "skirts": "lower_body",
    "full body": "full_body",
    "full_body": "full_body",
    "dress": "full_body",
    "dresses": "full_body",
    "jumpsuit": "full_body",
    "one piece": "full_body",
    "one_piece": "full_body",
    "suit": "full_body",
    "outer": "outer",
    "outerwear": "outer",
    "jacket": "outer",
    "jackets": "outer",
    "coat": "outer",
    "blazer": "outer",
    "blazers": "outer",
    "cardigan": "outer",
    "shoes": "shoes",
    "footwear": "shoes",
    "sneakers": "shoes",
    "boots": "shoes",
    "auto": "auto",
}


def normalize_garment_category(category: Optional[str]) -> str:
    if not category:
        return "upper_body"
    clean = category.strip().lower()
    return YOUCAM_CATEGORY_MAP.get(clean, "upper_body")


class VirtualTryOnProvider(abc.ABC):
    @abc.abstractmethod
    async def create_tryon_task(
        self,
        user_image_bytes: bytes,
        garment_image_bytes: bytes,
        user_filename: str = "user.jpg",
        garment_filename: str = "garment.jpg",
        garment_category: str = "upper body",
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
    Reference: https://docs.perfectcorp.com/develop/introduction
    Standard S2S Workflow:
    1. POST /file to initialize upload, obtain file_id and signed PUT URL.
    2. PUT raw image bytes to pre-signed URL.
    3. POST /task/cloth-v4 with src_file_id, ref_file_id, garment_category.
    4. GET /task/cloth-v4/{task_id} (or /task/{task_id}) to poll status.
    """

    def __init__(self, api_key: str, base_url: str):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Accept": "application/json",
        }

    async def _upload_file_bytes(
        self,
        image_bytes: bytes,
        filename: str,
        client: httpx.AsyncClient,
        content_type: str = "image/jpeg",
    ) -> str:
        """
        Uploads image bytes to YouCam via official S2S File API:
        1. Calls POST {base_url}/file to register file metadata.
        2. Uploads raw binary data via PUT to returned pre-signed URL.
        Falls back to direct multipart if endpoint returns file_id directly.
        """
        url = f"{self.base_url}/file"
        file_meta_payload = {
            "files": [
                {
                    "content_type": content_type,
                    "file_name": filename,
                    "file_size": len(image_bytes),
                }
            ]
        }

        resp = await client.post(
            url,
            headers={**self.headers, "Content-Type": "application/json"},
            json=file_meta_payload,
            timeout=30.0,
        )

        if resp.status_code == 200:
            data = resp.json()
            # Standard YouCam response structure: data.files[0]
            files_list = data.get("data", {}).get("files") or data.get("files")
            if files_list and isinstance(files_list, list) and len(files_list) > 0:
                first_file = files_list[0]
                file_id = first_file.get("file_id")
                requests_list = first_file.get("requests", [])
                if requests_list and isinstance(requests_list, list) and len(requests_list) > 0:
                    put_info = requests_list[0]
                    put_url = put_info.get("url")
                    put_method = put_info.get("method", "PUT").upper()
                    if put_url:
                        # Upload binary bytes to the pre-signed URL
                        upload_headers = {"Content-Type": content_type}
                        put_resp = await client.request(
                            put_method,
                            put_url,
                            content=image_bytes,
                            headers=upload_headers,
                            timeout=60.0,
                        )
                        put_resp.raise_for_status()
                        logger.info("Successfully uploaded %s to YouCam S3 pre-signed storage", filename)
                        return file_id

                if file_id:
                    return file_id

            # Direct file_id format fallback
            file_id = data.get("file_id") or data.get("data", {}).get("file_id")
            if file_id:
                return file_id

        # Multipart upload fallback for older or mock S2S gateways
        files_multipart = {"file": (filename, image_bytes, content_type)}
        mp_resp = await client.post(
            url,
            headers={"Authorization": f"Bearer {self.api_key}"},
            files=files_multipart,
            timeout=30.0,
        )
        mp_resp.raise_for_status()
        mp_data = mp_resp.json()
        file_id = (
            mp_data.get("file_id")
            or mp_data.get("url")
            or mp_data.get("data", {}).get("file_id")
        )
        if not file_id:
            raise RuntimeError(f"Could not retrieve file_id from YouCam response: {mp_data}")
        return file_id

    async def create_tryon_task(
        self,
        user_image_bytes: bytes,
        garment_image_bytes: bytes,
        user_filename: str = "user.jpg",
        garment_filename: str = "garment.jpg",
        garment_category: str = "upper body",
    ) -> Dict[str, Any]:
        if not self.api_key:
            raise ValueError("YouCam API Key is required to call YouCamTryOnProvider.")

        normalized_category = normalize_garment_category(garment_category)

        async with httpx.AsyncClient() as client:
            # 1. Upload user image bytes
            user_file_ref = await self._upload_file_bytes(
                user_image_bytes, user_filename, client
            )
            # 2. Upload garment image bytes
            garment_file_ref = await self._upload_file_bytes(
                garment_image_bytes, garment_filename, client
            )

            # 3. Create task (target /task/cloth-v4 with fallback to /task/clothes-vto)
            task_endpoints = [
                f"{self.base_url}/task/cloth-v4",
                f"{self.base_url}/task/clothes-vto",
                f"{self.base_url}/task/cloth",
            ]

            payload = {
                "src_file_id": user_file_ref,
                "ref_file_id": garment_file_ref,
                "garment_category": normalized_category,
            }

            resp = None
            last_err = None
            for ep in task_endpoints:
                try:
                    r = await client.post(ep, headers=self.headers, json=payload, timeout=30.0)
                    if r.status_code == 404:
                        continue
                    if r.status_code != 200:
                        logger.warning("YouCam endpoint %s returned status %d: %s", ep, r.status_code, r.text)
                    r.raise_for_status()
                    resp = r
                    break
                except Exception as e:
                    last_err = e
                    continue

            if resp is None:
                if last_err:
                    raise last_err
                raise RuntimeError("Failed to create YouCam try-on task across all candidate endpoints.")

            result = resp.json()
            task_id = (
                result.get("task_id")
                or result.get("data", {}).get("task_id")
                or result.get("data", {}).get("id")
            )

            if not task_id:
                raise RuntimeError(f"Unexpected YouCam response without task_id: {result}")

            return {
                "task_id": str(task_id),
                "status": "processing",
                "provider": "youcam",
            }

    async def get_task_status(self, task_id: str) -> Dict[str, Any]:
        if not self.api_key:
            raise ValueError("YouCam API Key is required.")

        candidate_urls = [
            f"{self.base_url}/task/cloth-v4/{task_id}",
            f"{self.base_url}/task/{task_id}",
        ]

        async with httpx.AsyncClient() as client:
            resp = None
            for url in candidate_urls:
                try:
                    r = await client.get(url, headers=self.headers, timeout=20.0)
                    if r.status_code == 404:
                        continue
                    r.raise_for_status()
                    resp = r
                    break
                except Exception:
                    continue

            if resp is None:
                return {
                    "task_id": task_id,
                    "status": "failed",
                    "result_url": None,
                    "error": "Task status query returned 404 or connection failed.",
                    "provider": "youcam",
                }

            data = resp.json()
            data_obj = data.get("data") if isinstance(data.get("data"), dict) else data

            # Status extraction from standard YouCam responses
            raw_status = (
                data_obj.get("task_status")
                or data_obj.get("status")
                or data.get("status")
                or "unknown"
            )
            raw_status_str = str(raw_status).lower()

            if raw_status_str in ["running", "in_progress", "pending"]:
                norm_status = "processing"
            elif raw_status_str in ["success", "completed", "done"]:
                norm_status = "success"
            else:
                norm_status = "failed"

            # Result URL extraction (safely checking if results is dict)
            result_url = None
            results_val = data_obj.get("results")
            if isinstance(results_val, dict):
                result_url = results_val.get("url")
            elif isinstance(results_val, str):
                result_url = results_val
            if not result_url:
                result_url = data_obj.get("result_url") or data_obj.get("url") or data.get("result_url")

            error_msg = (
                data_obj.get("error_message")
                or data_obj.get("error")
                or data.get("error")
                or data.get("message")
            )

            return {
                "task_id": task_id,
                "status": norm_status,
                "result_url": result_url,
                "error": str(error_msg) if error_msg else None,
                "provider": "youcam",
            }


class MockTryOnProvider(VirtualTryOnProvider):
    """
    Predictable mock provider for tests and safe offline development.
    Simulates asynchronous task lifecycle (pending -> processing -> success).
    Does NOT require live network calls or credentials.
    """

    _task_db: Dict[str, Dict[str, Any]] = {}

    async def create_tryon_task(
        self,
        user_image_bytes: bytes,
        garment_image_bytes: bytes,
        user_filename: str = "user.jpg",
        garment_filename: str = "garment.jpg",
        garment_category: str = "upper body",
    ) -> Dict[str, Any]:
        import uuid
        task_id = f"mock-tryon-{uuid.uuid4().hex[:10]}"
        self._task_db[task_id] = {
            "poll_count": 0,
            "status": "processing",
            "garment_category": garment_category,
            "user_bytes_len": len(user_image_bytes),
            "garment_bytes_len": len(garment_image_bytes),
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
                # Realistic placeholder URL that returns an actual image in tests
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
