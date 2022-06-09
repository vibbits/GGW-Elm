" Server configuration "

import secrets

from pydantic import BaseSettings, PostgresDsn


class Settings(BaseSettings):
    "Global HTTP API server configuration"

    DATABASE_URL: PostgresDsn = PostgresDsn(url="postgresql://test:test@test/test")

    API_SECRET: str = secrets.token_urlsafe(32)
    API_JWT_ALGORITHM: str = "HS256"
    API_TOKEN_EXPIRE: int = 7 * 24 * 60  # 7 days in minutes

    AUTH_REDIRECT_URI: str = "http://localhost:49999/oidc_login"

    MAX_TEMP_FILE_SIZE: int = 10 * 1024 * 1024


settings = Settings()
