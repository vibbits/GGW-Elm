" Main entry point. "

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

import app.router as ggw

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(ggw.router)
