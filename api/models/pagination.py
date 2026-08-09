from pydantic import BaseModel, Field


class PaginatedMeta(BaseModel):
    page: int
    page_size: int
    page_count: int
    total_count: int | None = Field(None)


class Paginated[T](BaseModel):
    data: list[T]
    meta: PaginatedMeta
