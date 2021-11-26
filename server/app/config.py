" Server configuration "

import secrets

from pydantic import BaseSettings


class Settings(BaseSettings):
    "Global HTTP API server configuration"

    DATABASE_URL: str = ""

    API_SECRET: str = secrets.token_urlsafe(32)
    API_JWT_ALGORITHM: str = "HS256"
    API_TOKEN_EXPIRE: int = 7 * 24 * 60  # 7 days in minutes

    AUTH_REDIRECT_URI: str

    MAX_TEMP_FILE_SIZE: int = 10 * 1024 * 1024


settings = Settings()
