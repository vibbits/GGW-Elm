from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app import deps, schemas, crud

router = APIRouter()


@router.get("/hello", response_model=schemas.User)
def hello(database: Session = Depends(deps.get_db)):
    """Test function that returns the user name."""
    return crud.get_user(database, 1)
