from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.internals.auth import AppUser, get_user
from app.models.pagination import Paginated, PaginatedMeta
from app.repositories.generated.models import Restaurant
from app.repositories.generated.restaurants import (
    CreateRestaurantParams,
    DeleteRestaurantParams,
    GetRestaurantParams,
    ListRestaurantsParams,
    UpdateRestaurantParams,
)
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
            arg=ListRestaurantsParams(limit=page_size, offset=(page - 1) * page_size)
        )
    ]
    return Paginated(
        data=data,
        meta=PaginatedMeta(page=page, page_size=page_size, page_count=len(data)),
    )


@router.get("/{id}", response_model=Restaurant | None)
async def get_restaurant(id: str, q: Queriers = Depends(get_queriers)):
    data = await q.restaurants.get_restaurant(arg=GetRestaurantParams(id=id))

    if data is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Restaurant with {id=} not found",
        )

    return data


@router.post("", response_model=Restaurant)
async def create_restaurant(
    body: CreateRestaurantParams,
    q: Queriers = Depends(get_queriers),
    user: AppUser = Depends(get_user),
):
    created = await q.restaurants.create_restaurant(
        arg=body.model_copy(update={"created_by_id": user.id})
    )
    await q.db.commit()
    return created


@router.patch("/{id}", response_model=Restaurant)
async def update_restaurant(
    id: str, body: UpdateRestaurantParams, q: Queriers = Depends(get_queriers)
):
    if id != body.id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="IDs do not match"
        )

    updated = await q.restaurants.update_restaurant(arg=body)
    await q.db.commit()
    if updated is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Restaurant with {id=} not found",
        )

    return updated


@router.delete("/{id}", response_model=Restaurant)
async def delete_restaurant(id: str, q: Queriers = Depends(get_queriers)):
    deleted = await q.restaurants.delete_restaurant(arg=DeleteRestaurantParams(id=id))
    await q.db.commit()
    return deleted
