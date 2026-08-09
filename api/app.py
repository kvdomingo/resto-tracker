from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from scalar_fastapi import Theme, get_scalar_api_reference

from routers import restaurants
from settings import settings

app = FastAPI(
    title="Resto Tracker",
    version="0.1.0",
    docs_url=None,
    redoc_url=None,
)


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


app.include_router(restaurants.router, prefix="/api")

if settings.PRODUCTION:
    app.mount("", StaticFiles(directory="static"), name="static")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
