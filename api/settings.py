from typing import Literal

from pydantic import PostgresDsn, SecretStr, computed_field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    PYTHON_ENV: Literal["development", "production"] = "production"

    DATABASE_HOST: str
    DATABASE_PORT: int
    DATABASE_USER: SecretStr
    DATABASE_PASSWORD: SecretStr
    DATABASE_NAME: str

    @computed_field
    @property
    def PRODUCTION(self) -> bool:
        return self.PYTHON_ENV == "production"

    @computed_field
    @property
    def DATABASE_URL(self) -> PostgresDsn:
        return PostgresDsn.build(
            scheme="postgresql+asyncpg",
            host=self.DATABASE_HOST,
            port=self.DATABASE_PORT,
            username=self.DATABASE_USER,
            password=self.DATABASE_PASSWORD,
            path=self.DATABASE_NAME,
        )


settings = Settings()
