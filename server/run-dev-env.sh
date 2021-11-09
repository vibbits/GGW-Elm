#!/bin/sh

export DATABASE_URL="sqlite:///ggw.sqlite?check_same_thread=false"
export AUTH_REDIRECT_URI="http://localhost:49999/"

# Initialise the database
poetry run alembic upgrade head

# Add the keycloak id provider
poetry run ggwc add-identity-provider --issuer http://localhost:8080/auth/realms/GGW --clientid golden-gate-demo --secret 9faae22b-3da0-44c8-b5a4-910f9060aae6 --name "Keycloak (Dev)"

# Add VIB Services Staging id provider
poetry run ggwc add-identity-provider --issuer https://services-staging.vib.be/ --clientid golden-gate-demo --secret thisissecret --name "VIB Services Staging"

# Add the admin auth by keycloak
poetry run ggwc create-admin --iss 1 --sub 4af3d9fb-beb3-4b59-af33-d325addbf1bb ggw

# Run the app
poetry run hypercorn main:app --reload
