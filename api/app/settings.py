from typing import Literal

from pydantic import PostgresDsn, SecretStr, computed_field, field_validator
from pydantic_settings import BaseSettings
from sqlalchemy import make_url


class Settings(BaseSettings):
    PYTHON_ENV: Literal["development", "production"] = "production"

    DATABASE_URL: PostgresDsn

    STYTCH_PROJECT_ID: str
    STYTCH_PUBLIC_TOKEN: str
    STYTCH_SECRET_TOKEN: SecretStr

    @computed_field
    @property
    def PRODUCTION(self) -> bool:
        return self.PYTHON_ENV == "production"

    @field_validator("DATABASE_URL", mode="before")
    def validate_database_url(cls, v: str) -> str:
        return (
            make_url(v)
            .set(drivername="postgresql+asyncpg", query={})
            .render_as_string(hide_password=False)
        )


settings = Settings()
