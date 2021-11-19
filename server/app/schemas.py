"Data schemas for HTTP interface"

from typing import List, Optional

from pydantic import BaseModel

# Users


class UserBase(BaseModel):
    name: Optional[str]
    role: str = "user"


class UserCreate(UserBase):
    iss: str  # Issuer
    sub: str  # Subject


class User(UserBase):
    id: int

    class Config:
        orm_mode = True


# Auth


class AuthorizationResponse(BaseModel):
    state: str
    code: str


class Token(BaseModel):
    access_token: str
    token_type: str
    user: User


class Provider(BaseModel):
    id: int
    name: str
    issuer: str
    clientid: str
    secret: str

    class Config:
        orm_mode = True


class LoginUrl(BaseModel):
    name: str
    url: str
