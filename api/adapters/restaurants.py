from geoalchemy2 import WKBElement, WKTElement
from geoalchemy2.shape import to_shape
from pydantic import BaseModel, field_validator, model_validator
from shapely import Point

from models.geometry import Coordinates


class RestaurantBranches(BaseModel):
    location: str
    geography: Coordinates | None = None

    @model_validator(mode="before")
    def from_composite(cls, v):
        # asyncpg decodes composite types to Record, which pydantic can't read
        return dict(v) if hasattr(v, "keys") else v

    @field_validator("geography", mode="before")
    def validate_geography(cls, v: WKBElement | WKTElement | bytes | None):
        if v is None:
            return None

        point = to_shape(WKBElement(v) if isinstance(v, bytes) else v)
        if not isinstance(point, Point):
            raise TypeError(f"expected a point, got {point.geom_type}")

        return Coordinates(latitude=point.y, longitude=point.x)
