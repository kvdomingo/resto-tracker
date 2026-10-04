import stytch
from fastapi import APIRouter, Depends, HTTPException, Request, Security, status
from fastapi.responses import PlainTextResponse, RedirectResponse
from pydantic import SecretStr

from app.interfaces.stytch import get_stytch_client
from app.internals.auth import AppUser, get_user
from app.repositories.generated.users import CreateUserParams, GetUserByIdpIdParams
from app.repositories.queriers import Queriers, get_queriers
from app.settings import settings

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/api-login", response_class=PlainTextResponse)
async def api_login():
    return settings.STYTCH_CALLBACK_URL.encoded_string()


@router.get("/callback", response_class=PlainTextResponse)
async def callback(
    request: Request,
    token: SecretStr,
    stytch: stytch.Client = Depends(get_stytch_client),
    q: Queriers = Depends(get_queriers),
):
    res = await stytch.oauth.authenticate_async(
        token=token.get_secret_value(), session_duration_minutes=120
    )
    if not res.is_success:
        if res.is_client_error:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST)
        if res.is_server_error:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR)

    idp_user = res.user

    db_user = await q.users.get_user_by_idp_id(
        arg=GetUserByIdpIdParams(idp_user_id=idp_user.user_id)
    )
    if db_user is None:
        db_user = await q.users.create_user(
            arg=CreateUserParams(
                idp_user_id=idp_user.user_id,
                email=idp_user.emails[0].email,
                name=None,
            )
        )
        await q.db.commit()
        if db_user is None:
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR)

    request.session.update(
        {
            "user_id": db_user.id,
            "idp_user_id": db_user.idp_user_id,
            "session_token": res.session_token,
            "session_jwt": res.session_jwt,
        }
    )
    return RedirectResponse(
        settings.APP_URL.encoded_string(), status_code=status.HTTP_303_SEE_OTHER
    )


@router.get("/logout", status_code=status.HTTP_303_SEE_OTHER)
async def logout(request: Request, stytch: stytch.Client = Depends(get_stytch_client)):
    token = request.session.get("session_token")
    if token is not None:
        await stytch.sessions.revoke_async(session_token=token)

    request.session.clear()
    return RedirectResponse(
        settings.APP_URL.encoded_string(), status_code=status.HTTP_303_SEE_OTHER
    )


@router.get(
    "/me",
    response_model=AppUser,
    dependencies=[Security(get_user, scopes=["authenticated"])],
)
async def me(user: AppUser = Depends(get_user)):
    return user
