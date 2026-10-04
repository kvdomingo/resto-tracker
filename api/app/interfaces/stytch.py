from stytch import Client

from app.settings import settings

client: Client | None = None


def get_stytch_client() -> Client:
    global client

    if client is None:
        client = Client(
            project_id=settings.STYTCH_PROJECT_ID,
            secret=settings.STYTCH_SECRET_TOKEN.get_secret_value(),
        )

    return client
