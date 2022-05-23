" API endpoints for administration "

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import schemas, deps, crud

router = APIRouter()


@router.get("/admin/users", response_model=schemas.AllUsers)
def get_all_users(
    database: Session = Depends(deps.get_db),
    _admin_user: schemas.User = Depends(deps.get_current_admin),
):
    "API endpoint for listing all registered users."
    users = crud.get_users(database)
    return schemas.AllUsers(label="users", data=users)


@router.get("/admin/groups", response_model=schemas.AllGroups)
def get_all_groups(
    database: Session = Depends(deps.get_db),
    _admin_user: schemas.User = Depends(deps.get_current_admin),
):
    "API endpoint for listing all groups of users."
    groups = crud.get_groups(database)
    return schemas.AllGroups(label="groups", data=groups)


@router.get("/admin/constructs", response_model=schemas.AllConstructs)
def get_all_constructs(
    database: Session = Depends(deps.get_db),
    _admin_user: schemas.User = Depends(deps.get_current_admin),
):
    "API endpoint for listing all vectors (constructs)."
    cons = crud.get_all_vectors(database)
    return schemas.AllConstructs(label="constructs", data=cons)
