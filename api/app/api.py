import importlib
import pkgutil
from datetime import timedelta

from fastapi import APIRouter, FastAPI
from fastapi.responses import PlainTextResponse
from scalar_fastapi import Theme, get_scalar_api_reference
from starlette.middleware.authentication import AuthenticationMiddleware
from starlette.middleware.sessions import SessionMiddleware

from app import routers
from app.internals.auth import StytchAuthBackend
from app.settings import settings

app = FastAPI(
    title="Resto Tracker",
    version="0.1.0",
    docs_url=None,
    redoc_url=None,
)
app.add_middleware(
    AuthenticationMiddleware,
    backend=StytchAuthBackend(),
)
app.add_middleware(
    SessionMiddleware,
    secret_key=settings.SECRET_KEY.get_secret_value(),
    session_cookie="session",
    max_age=int(timedelta(days=7).total_seconds()),
    path="/",
    same_site="strict",
    https_only=settings.PROD,
)


@app.get("/api/health", response_class=PlainTextResponse, tags=["utils"])
async def healthcheck():
    return "ok"


@app.get("/api/docs", include_in_schema=False)
async def docs():
    return get_scalar_api_reference(
        openapi_url=app.openapi_url,
        title=app.title,
        dark_mode=True,
        persist_auth=True,
        telemetry=False,
        theme=Theme.MARS,
    )


for info in pkgutil.iter_modules(routers.__path__):
    module = importlib.import_module(f"{routers.__name__}.{info.name}")
    if isinstance(getattr(module, "router", None), APIRouter):
        app.include_router(module.router, prefix="/api")

if settings.PROD:
    app.frontend("/", directory="static", fallback="index.html")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
