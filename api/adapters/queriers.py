from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from interfaces.postgres import get_db
from repositories.generated.restaurants import AsyncQuerier


def get_restaurant_querier(
    db: AsyncSession = Depends(get_db),
) -> AsyncQuerier[AsyncSession]:
    return AsyncQuerier(conn=db)
