from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from adapters.queriers import get_restaurant_querier
from models.pagination import Paginated, PaginatedMeta
from repositories.generated.models import Restaurant
from repositories.generated.restaurants import AsyncQuerier

router = APIRouter(
    prefix="/restaurants",
    tags=["restaurants"],
)


@router.get("", response_model=Paginated[Restaurant])
async def list_restaurants(
    querier: AsyncQuerier[AsyncSession] = Depends(get_restaurant_querier),
    page: Annotated[int, Query(ge=1)] = 1,
    page_size: Annotated[int, Query(ge=1, le=100)] = 10,
):
    data = [
        row
        async for row in querier.list_restaurants(
            limit=page_size, offset=(page - 1) * page_size
        )
    ]
    return Paginated(
        data=data,
        meta=PaginatedMeta(page=page, page_size=page_size, page_count=len(data)),
    )


@router.get("/{id}", response_model=Restaurant | None)
async def get_restaurant(
    id: str,
    querier: AsyncQuerier[AsyncSession] = Depends(get_restaurant_querier),
):
    data = await querier.get_restaurant(id=id)

    if data is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Restaurant with {id=} not found",
        )

    return data
