from collections.abc import Callable
from typing import Annotated

from fastapi import Depends

from app.models.pagination import Paginated, PaginatedMeta, PaginationRequestParams


def _paginate[T](
    data: list[T], pagination: Annotated[PaginationRequestParams, Depends()]
):
    return Paginated(
        data=data,
        meta=PaginatedMeta(
            page=pagination.page,
            page_size=pagination.page_size,
            page_count=len(data),
            total_count=None,  # TODO
        ),
    )


type Paginate[T] = Callable[[list[T]], Paginated[T]]


def paginate_factory[T](
    pagination: Annotated[PaginationRequestParams, Depends()],
) -> Paginate[T]:
    return lambda data: _paginate(data, pagination)
