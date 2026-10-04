from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.interfaces.postgres import get_db
from app.repositories.generated import restaurants, users


class Queriers:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.restaurants = restaurants.AsyncQuerier(conn=db)
        self.users = users.AsyncQuerier(conn=db)


def get_queriers(db: AsyncSession = Depends(get_db)) -> Queriers:
    return Queriers(db)
