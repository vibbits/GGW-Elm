#!/bin/sh

export DATABASE_URL="sqlite:///ggw.sqlite?check_same_thread=false"
export AUTH_REDIRECT_URI="http://localhost:49999/oidc_login"

# Initialise the database
poetry run alembic upgrade head

# Add the keycloak id provider
poetry run ggwc add-identity-provider --issuer http://localhost:8080/auth/realms/GGW --clientid golden-gate-demo --secret 9faae22b-3da0-44c8-b5a4-910f9060aae6 --name "Keycloak (Dev)"

# Add VIB Services Staging id provider
poetry run ggwc add-identity-provider --issuer https://services-staging.vib.be/ --clientid golden-gate-demo --secret thisissecret --name "VIB Services Staging"

# Add the admin auth by keycloak
poetry run ggwc create-admin --iss 1 --sub 4af3d9fb-beb3-4b59-af33-d325addbf1bb ggw

# Populate the database
poetry run ggwc import0 ./Test_data/MP-G0-elements_Import_File.csv  ./Test_data/Example_Level_0/ 4af3d9fb-beb3-4b59-af33-d325addbf1bb

# Run the app
poetry run hypercorn --bind "0.0.0.0:8000" main:app --reload
