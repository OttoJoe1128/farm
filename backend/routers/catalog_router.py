from __future__ import annotations

import json
import os
import re
from typing import Any, Callable, Dict, List, Literal, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

CATALOG_FILE = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "catalog", "asset_types.json")
TYPE_ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]{1,40}$")

FieldType = Literal["text", "textarea", "number", "integer", "date", "datetime", "select", "boolean", "url"]
GeometryType = Literal["Point", "LineString", "Polygon"]


class FormField(BaseModel):
    key: str = Field(pattern=r"^[a-z][a-z0-9_]{0,60}$")
    label: str
    type: FieldType = "text"
    required: bool = False
    unit: Optional[str] = None
    min: Optional[float] = None
    max: Optional[float] = None
    options: Optional[List[str]] = None
    help: Optional[str] = None


class FormSection(BaseModel):
    key: str = Field(pattern=r"^[a-z][a-z0-9_]{0,60}$")
    label: str
    fields: List[FormField]


class AssetType(BaseModel):
    id: str
    label: str
    category: str = "genel"
    asset_type: Literal["living", "non_living"] = "non_living"
    icon: str
    color: str = Field(pattern=r"^#[0-9A-Fa-f]{6}$")
    geometry_types: List[GeometryType] = Field(min_length=1)
    disabled: bool = False
    form: List[FormSection] = []


class ValidateRequest(BaseModel):
    type_id: str
    values: Dict[str, Dict[str, Any]] = {}


def load_default_catalog() -> Dict[str, Dict[str, Any]]:
    with open(CATALOG_FILE, "r", encoding="utf-8") as file_obj:
        raw: Dict[str, Any] = json.load(file_obj)
    return {item["id"]: AssetType(**item).model_dump() for item in raw["types"]}


def validate_values(type_def: Dict[str, Any], values: Dict[str, Dict[str, Any]]) -> List[Dict[str, str]]:
    errors: List[Dict[str, str]] = []
    for section in type_def.get("form", []):
        section_values: Dict[str, Any] = dict(values.get(section["key"]) or {})
        for field in section["fields"]:
            path = f"{section['key']}.{field['key']}"
            value: Any = section_values.get(field["key"])
            if value is None or (isinstance(value, str) and value.strip() == ""):
                if field.get("required"):
                    errors.append({"field": path, "error": "required"})
                continue
            field_type: str = field.get("type", "text")
            if field_type in ("number", "integer"):
                try:
                    number = float(value)
                except (TypeError, ValueError):
                    errors.append({"field": path, "error": "not_a_number"})
                    continue
                if field_type == "integer" and not number.is_integer():
                    errors.append({"field": path, "error": "not_an_integer"})
                if field.get("min") is not None and number < field["min"]:
                    errors.append({"field": path, "error": "below_min"})
                if field.get("max") is not None and number > field["max"]:
                    errors.append({"field": path, "error": "above_max"})
            elif field_type == "select" and str(value) not in (field.get("options") or []):
                errors.append({"field": path, "error": "invalid_option"})
            elif field_type == "boolean" and not isinstance(value, bool):
                errors.append({"field": path, "error": "not_a_boolean"})
    return errors


def create_catalog_router(
    *,
    get_current_user: Callable[..., Dict[str, Any]],
    require_admin: Callable[..., Dict[str, Any]],
    get_storage: Callable[[], Any],
) -> APIRouter:
    router = APIRouter(prefix="/api/v1/catalog")
    defaults = load_default_catalog()

    def merged(include_disabled: bool = False) -> Dict[str, Dict[str, Any]]:
        result: Dict[str, Dict[str, Any]] = {k: dict(v, source="default") for k, v in defaults.items()}
        for type_id, doc in get_storage().load_catalog_overrides().items():
            result[type_id] = dict(doc, source="custom")
        if not include_disabled:
            result = {k: v for k, v in result.items() if not v.get("disabled")}
        return result

    def get_type(type_id: str) -> Dict[str, Any]:
        item = merged(include_disabled=True).get(type_id)
        if item is None:
            raise HTTPException(status_code=404, detail="Varlik tipi bulunamadi.")
        return item

    @router.get("/asset-types")
    def list_asset_types(include_disabled: bool = False, _: Dict[str, Any] = Depends(get_current_user)):
        types = list(merged(include_disabled).values())
        return {"types": types, "count": len(types)}

    @router.get("/asset-types/{type_id}")
    def asset_type_detail(type_id: str, _: Dict[str, Any] = Depends(get_current_user)):
        return get_type(type_id)

    @router.put("/asset-types/{type_id}")
    def upsert_asset_type(type_id: str, body: AssetType, _: Dict[str, Any] = Depends(require_admin)):
        if not TYPE_ID_PATTERN.match(type_id) or body.id != type_id:
            raise HTTPException(status_code=422, detail="type_id gecersiz veya govdedeki id ile uyusmuyor.")
        overrides = get_storage().load_catalog_overrides()
        overrides[type_id] = body.model_dump()
        get_storage().save_catalog_overrides(overrides)
        return get_type(type_id)

    @router.delete("/asset-types/{type_id}")
    def reset_asset_type(type_id: str, _: Dict[str, Any] = Depends(require_admin)):
        overrides = get_storage().load_catalog_overrides()
        if type_id not in overrides:
            raise HTTPException(status_code=404, detail="Ozel varlik tipi bulunamadi.")
        overrides.pop(type_id)
        get_storage().save_catalog_overrides(overrides)
        return {"status": "deleted", "type_id": type_id, "reverted_to_default": type_id in defaults}

    @router.post("/validate")
    def validate_asset_values(body: ValidateRequest, _: Dict[str, Any] = Depends(get_current_user)):
        errors = validate_values(get_type(body.type_id), body.values)
        return {"valid": errors == [], "errors": errors}

    return router
