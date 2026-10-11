from typing import Annotated

from fastapi import APIRouter, Body, Depends, Request, Security

from app.internals.auth import get_user
from app.internals.pagination import Paginate, paginate_factory
from app.internals.utils import alist
from app.models.pagination import Paginated, PaginationRequestParams
from app.repositories.generated.group_memberships import (
    AddToGroupParams,
    RemoveFromGroupParams,
)
from app.repositories.generated.groups import (
    CreateGroupParams,
    CreateGroupRow,
    DeleteGroupParams,
    GetGroupParams,
    GetGroupRow,
    ListMyGroupsParams,
    UpdateGroupParams,
)
from app.repositories.generated.models import Group, GroupMembership
from app.repositories.queriers import Queriers, get_queriers

router = APIRouter(
    prefix="/groups",
    tags=["groups"],
)


@router.get(
    "",
    response_model=Paginated[Group],
    dependencies=[Security(get_user, scopes=["authenticated"])],
)
async def list_groups(
    request: Request,
    pagination: Annotated[PaginationRequestParams, Depends()],
    q: Queriers = Depends(get_queriers),
    paginate: Paginate[Group] = Depends(paginate_factory),
):
    results = await alist(
        q.groups.list_my_groups(
            arg=ListMyGroupsParams(
                user_id=request.user.id,
                limit=pagination.page_size,
                offset=pagination.offset,
            )
        )
    )
    return paginate(results)


@router.get(
    "/{id}",
    response_model=GetGroupRow,
    dependencies=[Security(get_user, scopes=["authenticated"])],
)
async def get_group(request: Request, id: str, q: Queriers = Depends(get_queriers)):
    return await q.groups.get_group(
        arg=GetGroupParams(id=id, created_by_id=request.user.id)
    )


@router.post(
    "",
    response_model=CreateGroupRow,
    dependencies=[Security(get_user, scopes=["authenticated"])],
)
async def create_group(
    request: Request,
    name: Annotated[str, Body(embed=True)],
    q: Queriers = Depends(get_queriers),
):
    created = await q.groups.create_group(
        arg=CreateGroupParams(created_by_id=request.user.id, name=name)
    )
    await q.db.commit()
    return created


@router.patch(
    "/{id}",
    response_model=Group,
    dependencies=[Security(get_user, scopes=["authenticated"])],
)
async def update_group(
    request: Request,
    id: str,
    name: Annotated[str, Body(embed=True)],
    q: Queriers = Depends(get_queriers),
):
    updated = await q.groups.update_group(
        arg=UpdateGroupParams(id=id, name=name, created_by_id=request.user.id)
    )
    await q.db.commit()
    return updated


@router.delete(
    "/{id}",
    response_model=Group,
    dependencies=[Security(get_user, scopes=["authenticated"])],
)
async def delete_group(
    request: Request,
    id: str,
    q: Queriers = Depends(get_queriers),
):
    deleted = await q.groups.delete_group(
        arg=DeleteGroupParams(id=id, created_by_id=request.user.id)
    )
    await q.db.commit()
    return deleted


@router.post("/{id}/members", response_model=list[GroupMembership])
async def add_group_member(
    request: Request,
    id: str,
    users: Annotated[list[str], Body(embed=True)],
    q: Queriers = Depends(get_queriers),
):
    created = await alist(
        q.group_memberships.add_to_group(
            arg=[
                AddToGroupParams(id=id, created_by_id=request.user.id, user_id=user_id)
                for user_id in users
            ]
        )
    )
    await q.db.commit()
    return created


@router.delete("/{id}/members", response_model=list[GroupMembership])
async def remove_group_member(
    request: Request,
    id: str,
    users: Annotated[list[str], Body(embed=True)],
    q: Queriers = Depends(get_queriers),
):
    deleted = await alist(
        q.group_memberships.remove_from_group(
            arg=[
                RemoveFromGroupParams(
                    id=id, created_by_id=request.user.id, user_id=user_id
                )
                for user_id in users
            ]
        )
    )
    await q.db.commit()
    return deleted
