from pydantic import BaseModel, Field


class Coordinates(BaseModel):
    latitude: float
    longitude: float


class Bbox(BaseModel):
    n: float = Field(ge=-90, le=90)
    e: float = Field(ge=-180, le=180)
    w: float = Field(ge=-180, le=180)
    s: float = Field(ge=-90, le=90)
