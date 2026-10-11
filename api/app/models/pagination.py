from pydantic import BaseModel, Field, computed_field


class PaginatedMeta(BaseModel):
    page: int
    page_size: int
    page_count: int
    total_count: int | None = Field(None)


class Paginated[T](BaseModel):
    data: list[T]
    meta: PaginatedMeta


class PaginationRequestParams(BaseModel):
    page: int = Field(ge=1)
    page_size: int = Field(ge=1, le=100)

    @computed_field
    @property
    def offset(self) -> int:
        return (self.page - 1) * self.page_size
