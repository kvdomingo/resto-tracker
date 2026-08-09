from pydantic import PostgresDsn, SecretStr, computed_field
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_HOST: str
    DATABASE_PORT: int
    DATABASE_USER: SecretStr
    DATABASE_PASSWORD: SecretStr
    DATABASE_NAME: str

    @property
    @computed_field
    def DATABASE_URL(self) -> PostgresDsn:
        return PostgresDsn.build(
            scheme="postgresql+asyncpg",
            host=self.DATABASE_HOST,
            port=self.DATABASE_PORT,
            username=self.DATABASE_USER,
            password=self.DATABASE_PASSWORD,
            path=self.DATABASE_NAME,
        )
