from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)

from settings import settings

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
