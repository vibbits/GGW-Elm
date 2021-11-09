" Database data model "

from datetime import datetime
from typing import Optional

from sqlalchemy import Column, DateTime, Integer, String, UniqueConstraint

from app.database import Base


class User(Base):
    "An authenticated user"
    __tablename__ = "users"

    id: int = Column(Integer, primary_key=True, index=True)
    iss: str = Column(String, nullable=False, index=True)
    sub: str = Column(String, nullable=False, index=True)
    created: datetime = Column(DateTime, nullable=False, default=datetime.now())
    name: Optional[str] = Column(String)
    role: str = Column(String, nullable=False, default="user")

    __table_args__ = (UniqueConstraint("iss", "sub", name="login_id"),)


class IdentityProvider(Base):
    "Accepted identity providers"
    __tablename__ = "providers"

    id: int = Column(Integer, primary_key=True, index=True)
    name: str = Column(String, nullable=False, unique=True)
    issuer: str = Column(String, nullable=False)
    clientid: str = Column(String, nullable=False)
    secret: str = Column(String, nullable=False)
