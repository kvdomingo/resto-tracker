from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.interfaces.postgres import get_db
from app.repositories.generated import (
    group_memberships,
    groups,
    restaurant_branches,
    restaurant_tags,
    restaurant_visits,
    restaurants,
    reviews,
    tags,
    users,
)


class Queriers:
    def __init__(self, db: AsyncSession):
        self.db = db
        self.restaurants = restaurants.AsyncQuerier(conn=db)
        self.users = users.AsyncQuerier(conn=db)
        self.groups = groups.AsyncQuerier(conn=db)
        self.group_memberships = group_memberships.AsyncQuerier(conn=db)
        self.restaurant_tags = restaurant_tags.AsyncQuerier(conn=db)
        self.restaurant_visits = restaurant_visits.AsyncQuerier(conn=db)
        self.restaurant_branches = restaurant_branches.AsyncQuerier(conn=db)
        self.reviews = reviews.AsyncQuerier(conn=db)
        self.tags = tags.AsyncQuerier(conn=db)


def get_queriers(db: AsyncSession = Depends(get_db)) -> Queriers:
    return Queriers(db)
