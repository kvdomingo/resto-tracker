from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from sqlalchemy import event
from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.util import await_only

from app.settings import settings

engine: AsyncEngine | None = None
sessionmaker: async_sessionmaker[AsyncSession] | None = None


def get_engine() -> AsyncEngine:
    global engine

    if engine is None:
        engine = create_async_engine(
            url=settings.DATABASE_URL.encoded_string(),
            echo=not settings.PRODUCTION,
            echo_pool=not settings.PRODUCTION,
            hide_parameters=False,
            plugins=["geoalchemy2"],
        )

        @event.listens_for(engine.sync_engine, "connect")
        def register_geography_codec(dbapi_connection, _):
            await_only(
                dbapi_connection.driver_connection.set_type_codec(
                    "geography",
                    schema="public",
                    encoder=lambda v: v,
                    decoder=lambda v: v,
                    format="binary",
                )
            )

    return engine


def get_sessionmaker() -> async_sessionmaker[AsyncSession]:
    global sessionmaker

    if sessionmaker is None:
        sessionmaker = async_sessionmaker(bind=get_engine())

    return sessionmaker


async def get_db() -> AsyncGenerator[AsyncSession]:
    db = get_sessionmaker()()
    yield db
    await db.close()


get_db_ctx = asynccontextmanager(get_db)
