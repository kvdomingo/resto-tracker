from typing import Annotated

from fastapi import APIRouter, Body, Depends, HTTPException, Security, status

from app.internals.auth import AppUser, get_user
from app.internals.pagination import Paginate, paginate_factory
from app.internals.utils import alist
from app.models.geometry import Bbox
from app.models.pagination import Paginated, PaginationRequestParams
from app.repositories.generated.models import Restaurant, RestaurantBranch
from app.repositories.generated.restaurant_branches import (
    AddRestaurantBranchesParams,
    DeleteRestaurantBranchesParams,
)
from app.repositories.generated.restaurants import (
    CreateRestaurantParams,
    DeleteRestaurantParams,
    GetRestaurantParams,
    GetRestaurantRow,
    ListRestaurantsInAreaParams,
    ListRestaurantsInAreaRow,
    UpdateRestaurantParams,
)
from app.repositories.queriers import Queriers, get_queriers

router = APIRouter(
    prefix="/restaurants",
    tags=["restaurants"],
)


@router.get("", response_model=Paginated[ListRestaurantsInAreaRow])
async def list_restaurants(
    bbox: Annotated[Bbox, Depends()],
    pagination: Annotated[PaginationRequestParams, Depends()],
    q: Queriers = Depends(get_queriers),
    paginate: Paginate[ListRestaurantsInAreaRow] = Depends(paginate_factory),
):
    data = await alist(
        q.restaurants.list_restaurants_in_area(
            arg=ListRestaurantsInAreaParams(
                limit=pagination.page_size,
                offset=pagination.offset,
                n=bbox.n,
                e=bbox.e,
                w=bbox.w,
                s=bbox.s,
            )
        )
    )
    return paginate(data)


@router.get("/{id}", response_model=GetRestaurantRow)
async def get_restaurant(id: str, q: Queriers = Depends(get_queriers)):
    return await q.restaurants.get_restaurant(arg=GetRestaurantParams(id=id))


@router.post(
    "",
    response_model=Restaurant,
    dependencies=[Security(get_user, scopes=["authenticated", "admin"])],
)
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


@router.patch(
    "/{id}",
    response_model=Restaurant,
    dependencies=[Security(get_user, scopes=["authenticated", "admin"])],
)
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


@router.delete(
    "/{id}",
    response_model=Restaurant,
    dependencies=[Security(get_user, scopes=["authenticated", "admin"])],
)
async def delete_restaurant(id: str, q: Queriers = Depends(get_queriers)):
    deleted = await q.restaurants.delete_restaurant(arg=DeleteRestaurantParams(id=id))
    await q.db.commit()
    return deleted


@router.post(
    "/{id}/branches",
    response_model=list[RestaurantBranch],
    dependencies=[Security(get_user, scopes=["authenticated", "admin"])],
)
async def create_restaurant_branches(
    id: str,
    branches: Annotated[list[AddRestaurantBranchesParams], Body(embed=True)],
    q: Queriers = Depends(get_queriers),
):
    if any(branch.restaurant_id != id for branch in branches):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="All restaurant IDs must match the path parameter.",
        )

    created = await alist(
        q.restaurant_branches.add_restaurant_branches(
            arg=[
                AddRestaurantBranchesParams(
                    restaurant_id=branch.restaurant_id,
                    label=branch.label,
                    geography=branch.geography,
                )
                for branch in branches
            ]
        )
    )
    await q.db.commit()
    return created


@router.delete(
    "/branches",
    response_model=list[RestaurantBranch],
    dependencies=[Security(get_user, scopes=["authenticated", "admin"])],
)
async def delete_restaurant_branches(
    branches: Annotated[list[DeleteRestaurantBranchesParams], Body(embed=True)],
    q: Queriers = Depends(get_queriers),
):
    deleted = await alist(
        q.restaurant_branches.delete_restaurant_branches(
            arg=[DeleteRestaurantBranchesParams(id=branch.id) for branch in branches]
        )
    )
    await q.db.commit()
    return deleted
