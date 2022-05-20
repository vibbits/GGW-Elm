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
