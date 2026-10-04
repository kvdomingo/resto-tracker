from fastapi import HTTPException, Request, status
from fastapi.security import SecurityScopes
from starlette.authentication import AuthCredentials, AuthenticationBackend, BaseUser
from starlette.requests import HTTPConnection

from app.interfaces.postgres import get_db_ctx
from app.interfaces.stytch import get_stytch_client
from app.repositories.generated.models import User
from app.repositories.generated.users import AsyncQuerier, GetUserByIdParams


class AppUser(BaseUser, User):
    @property
    def is_authenticated(self) -> bool:
        return True

    @property
    def display_name(self) -> str:
        return self.name or self.email

    @property
    def identity(self) -> str:
        return self.idp_user_id


class StytchAuthBackend(AuthenticationBackend):
    async def authenticate(
        self, conn: HTTPConnection
    ) -> tuple[AuthCredentials, AppUser] | None:
        jwt = conn.session.get("session_jwt")
        user_id = conn.session.get("user_id")
        if jwt is None or user_id is None:
            return None

        stytch = get_stytch_client()
        res = await stytch.sessions.authenticate_async(session_jwt=jwt)
        if not res.is_success:
            return None

        async with get_db_ctx() as db:
            q = AsyncQuerier(conn=db)
            db_user = await q.get_user_by_id(arg=GetUserByIdParams(id=user_id))
            if not db_user:
                return None

            return AuthCredentials(
                ["authenticated", *res.user.roles]
            ), AppUser.model_validate(db_user, from_attributes=True)


def get_user(request: Request, scopes: SecurityScopes) -> AppUser:
    if not request.user.is_authenticated:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    if not set(scopes.scopes) <= set(request.auth.scopes):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN)
    return request.user
