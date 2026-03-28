import os
import uuid
from pathlib import Path

from fastapi import UploadFile, HTTPException, status

from app.config import settings


def get_upload_dir(subfolder: str = "") -> Path:
    path = Path(settings.UPLOAD_DIR) / subfolder
    path.mkdir(parents=True, exist_ok=True)
    return path


async def save_upload_file(
    file: UploadFile,
    subfolder: str,
    allowed_types: list[str],
    max_size: int | None = None,
) -> dict:
    """Save uploaded file, return metadata dict."""
    if max_size is None:
        max_size = settings.max_file_size_bytes

    # Validate MIME type
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File type '{file.content_type}' not allowed. Allowed: {allowed_types}",
        )

    # Read content
    content = await file.read()

    # Validate size
    if len(content) > max_size:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File too large. Max size: {settings.MAX_FILE_SIZE_MB}MB",
        )

    # Generate safe filename
    ext = os.path.splitext(file.filename or "file")[1].lower()
    safe_name = f"{uuid.uuid4().hex}{ext}"

    # Save
    upload_dir = get_upload_dir(subfolder)
    file_path = upload_dir / safe_name

    with open(file_path, "wb") as f:
        f.write(content)

    return {
        "file_name": safe_name,
        "original_name": file.filename or "unknown",
        "mime_type": file.content_type or "application/octet-stream",
        "file_size": len(content),
        "file_url": f"/uploads/{subfolder}/{safe_name}",
    }


def delete_upload_file(file_url: str) -> bool:
    """Delete a file by its URL path. Returns True if deleted."""
    try:
        # file_url looks like /uploads/listings/abc.jpg
        rel_path = file_url.lstrip("/")
        if os.path.exists(rel_path):
            os.remove(rel_path)
            return True
    except Exception:
        pass
    return False
