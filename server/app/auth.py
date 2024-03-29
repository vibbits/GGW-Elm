" API endpoints dealing with authentication and authorization. "

from typing import List
import asyncio

from fastapi import APIRouter, Depends, HTTPException, status
from jose.exceptions import ExpiredSignatureError, JWTClaimsError, JWTError
from sqlalchemy.orm import Session
import httpx
import jose

from app import crud, deps, oidc, schemas

router = APIRouter()


@router.get("/login", response_model=List[schemas.LoginUrl])
async def get_login_url(
    db: Session = Depends(deps.get_db),
    httpc: httpx.AsyncClient = Depends(deps.get_http_client),
):
    providers = crud.get_identity_providers(db)
    configs = await asyncio.gather(
        *[oidc.configuration(httpc, provider.issuer) for provider in providers]
    )
    return [
        schemas.LoginUrl(
            id=provider.id,
            name=provider.name,
            issuer=provider.issuer,
            url=oidc.login_url(
                config["authorization_endpoint"], schemas.Provider.from_orm(provider)
            ),
        )
        for (provider, config) in zip(providers, configs)
        if config is not None
    ]


@router.post(
    "/authorize", summary="Get an API access token", response_model=schemas.Token
)
async def verify_authorization(
    body: schemas.AuthorizationResponse,
    database: Session = Depends(deps.get_db),
    http_client: httpx.AsyncClient = Depends(deps.get_http_client),
) -> schemas.Token:
    "Submit the 'code' from the authorization service to get an API access token."
    if (state := oidc.decode_state(body.state)) is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Could not decode state"
        )

    if (provider := crud.get_provider_by_id(database, state.get("provider"))) is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"No provider with id={state.get('provider')}",
        )

    if (config := await oidc.configuration(http_client, provider.issuer)) is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Could not query identity provider",
        )

    token_request = (
        oidc.TokenRequestBuilder()
        .with_clientid(provider.clientid)
        .with_secret(provider.secret)
        .with_code(body.code)
        .build()
    )

    if "error" in (response := await oidc.token(http_client, config, token_request)):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=response.get("error_description"),
        )

    try:
        id_token = jose.jwt.decode(
            response["id_token"],
            await oidc.jwks(http_client, config),
            audience=provider.clientid,
            access_token=response["access_token"],
        )
    except (JWTError, JWTClaimsError, ExpiredSignatureError) as err:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(err))

    userinfo = await oidc.userinfo(
        http_client, config, access_token=response["access_token"]
    )
    user = schemas.UserCreate(**{**id_token, **userinfo, "role": "user"})

    if (
        db_user := crud.get_user_by_identity(
            database, issuer=user.iss, subject=user.sub
        )
    ) is None:
        # Create a new user in the database
        db_user = crud.create_user(database, user=user)

    authed_user = schemas.User.from_orm(db_user)
    access_token = oidc.create_access_token(data=authed_user)

    return schemas.Token(
        access_token=access_token,
        token_type="bearer",
        user=authed_user,
    )
