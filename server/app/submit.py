from tempfile import SpooledTemporaryFile

from fastapi import APIRouter, File, UploadFile, Depends
from sqlalchemy.orm import Session

from app import deps, genbank, crud, model
from app.config import settings

router = APIRouter()


@router.post("/submit/vector")
async def submit_vector(
    *,
    database: Session = Depends(deps.get_db),
    current_user: model.User = Depends(deps.get_current_user),
    genbank_file: UploadFile = File(...),
):
    with SpooledTemporaryFile(
        max_size=settings.MAX_TEMP_FILE_SIZE, mode="rw", encoding="utf8"
    ) as genbank_temp:
        data = await genbank_file.read()
        if isinstance(data, str):
            genbank_temp.write(data)
        else:
            genbank_temp.write(data.decode("utf8"))

        genbank_temp.seek(0)
        vector = genbank.convert_gbk_to_vector(genbank_temp)
    crud.add_vector(database, vector, user=current_user)
    print(f"Vector '{vector.name}' has been added to the database")
