"""Optional S3-compatible object storage (Neon Object Storage) for uploaded photos.

Enabled only when the AWS-standard variables injected by Neon are present
(AWS_ENDPOINT_URL_S3, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY). Otherwise
callers keep using the local UPLOAD_DIR, so nothing changes for local dev/tests.
"""
import os
from typing import Optional

DEFAULT_BUCKET = "photos"


def is_enabled() -> bool:
    return all(
        os.getenv(name, "").strip() != ""
        for name in ("AWS_ENDPOINT_URL_S3", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY")
    )


def bucket_name() -> str:
    return os.getenv("PHOTO_BUCKET", DEFAULT_BUCKET).strip() or DEFAULT_BUCKET


def _client():
    import boto3
    from botocore.config import Config

    # Neon Object Storage requires path-style addressing and SigV4.
    return boto3.client(
        "s3",
        endpoint_url=os.environ["AWS_ENDPOINT_URL_S3"],
        region_name=os.getenv("AWS_REGION", "us-east-2"),
        config=Config(signature_version="s3v4", s3={"addressing_style": "path"}),
    )


def put_object(key: str, content: bytes, content_type: str) -> None:
    _client().put_object(
        Bucket=bucket_name(),
        Key=key,
        Body=content,
        ContentType=content_type or "application/octet-stream",
    )


def presigned_get_url(key: str, expires_in: int = 3600) -> str:
    return _client().generate_presigned_url(
        "get_object",
        Params={"Bucket": bucket_name(), "Key": key},
        ExpiresIn=expires_in,
    )


def delete_object(key: str) -> None:
    _client().delete_object(Bucket=bucket_name(), Key=key)


def safe_key(user_id: str, file_name: str) -> Optional[str]:
    cleaned_user = "".join(ch for ch in str(user_id) if ch.isalnum() or ch in "-_")
    if cleaned_user == "":
        return None
    return f"assets/{cleaned_user}/{file_name}"
