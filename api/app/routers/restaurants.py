from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.models.pagination import Paginated, PaginatedMeta
from app.repositories.generated.models import Restaurant
from app.repositories.queriers import Queriers, get_queriers

router = APIRouter(
    prefix="/restaurants",
    tags=["restaurants"],
)


@router.get("", response_model=Paginated[Restaurant])
async def list_restaurants(
    q: Queriers = Depends(get_queriers),
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 10,
):
    data = [
        row
        async for row in q.restaurants.list_restaurants(
            limit=page_size, offset=(page - 1) * page_size
        )
    ]
    return Paginated(
        data=data,
        meta=PaginatedMeta(page=page, page_size=page_size, page_count=len(data)),
    )


@router.get("/{id}", response_model=Restaurant | None)
async def get_restaurant(id: str, q: Queriers = Depends(get_queriers)):
    data = await q.restaurants.get_restaurant(id=id)

    if data is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Restaurant with {id=} not found",
        )

    return data
