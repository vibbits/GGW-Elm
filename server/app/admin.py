" API endpoints for administration "

from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import schemas, deps, crud

router = APIRouter()


@router.get("/admin/users", response_model=schemas.AllUsers)
def get_all_users(
    db: Session = Depends(deps.get_db),
    admin_user: schemas.User = Depends(deps.get_current_admin),
):
    users = crud.get_users(db)
    return schemas.AllUsers(label="users", data=users)


@router.get("/admin/groups", response_model=schemas.AllGroups)
def get_all_groups(
    db: Session = Depends(deps.get_db),
    admin_user: schemas.User = Depends(deps.get_current_admin),
):
    groups = crud.get_groups(db)
    return schemas.AllGroups(label="groups", data=groups)


@router.get("/admin/constructs", response_model=schemas.AllConstructs)
def get_all_constructs(
    db: Session = Depends(deps.get_db),
    admin_user: schemas.User = Depends(deps.get_current_admin),
):
    cons = crud.get_all_vectors(db)
    result = schemas.AllConstructs(label="constructs", data=cons)
    result.update_forward_refs()
    return result
