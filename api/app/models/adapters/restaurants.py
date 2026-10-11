from pydantic import BaseModel

from app.models.geometry import Coordinates


class RestaurantBranch(BaseModel):
    id: str
    restaurant_id: str
    label: str
    geography: Coordinates
