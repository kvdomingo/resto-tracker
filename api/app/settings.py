from typing import Literal

from pydantic import HttpUrl, PostgresDsn, SecretStr, computed_field, field_validator
from pydantic_settings import BaseSettings
from sqlalchemy import make_url


class Settings(BaseSettings):
    PYTHON_ENV: Literal["development", "production"] = "production"
    SECRET_KEY: SecretStr

    DATABASE_URL: PostgresDsn

    STYTCH_PROJECT_ID: str
    STYTCH_PUBLIC_TOKEN: str
    STYTCH_SECRET_TOKEN: SecretStr
    STYTCH_CALLBACK_URL: HttpUrl
    APP_URL: HttpUrl

    @field_validator("DATABASE_URL", mode="before")
    def validate_database_url(cls, v: str) -> str:
        return (
            make_url(v)
            .set(drivername="postgresql+asyncpg", query={})
            .render_as_string(hide_password=False)
        )

    @computed_field
    @property
    def DEV(self) -> bool:
        return self.PYTHON_ENV == "development"

    @computed_field
    @property
    def PROD(self) -> bool:
        return self.PYTHON_ENV == "production"

    @computed_field
    @property
    def STYTCH_API_BASE_URL(self) -> str:
        return "https://api.stytch.com" if self.PROD else "https://test.stytch.com"


settings = Settings()
