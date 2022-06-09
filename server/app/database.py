" Database connection "

import time
from datetime import datetime, timedelta

from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.engine import URL
from sqlalchemy_utils import database_exists, create_database

from app.config import settings

engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def init_database(url: str):
    "Create a database from a URL if it doesn't exist"
    if not database_exists(url):
        create_database(url)


def wait_for_database_up(url: URL, timeout: timedelta = timedelta(seconds=5)) -> bool:
    """
    Checks if we can connect to the database.
    This is especially important for Docker since the database
    may be ready to accept connections only after we try to
    connect to it.
    """
    started = datetime.now()

    # Null out the database so raw_connection doesnt error if it doesnt exist
    # We will create the database later if it doesn't exist.
    # We only need to know if we can connect to the DBMS now.
    url_ = URL(
        drivername=url.drivername,
        username=url.username,
        password=url.password,
        host=url.host,
        port=url.port,
        query=url.query,
    )
    print(repr(url_))

    connected = False
    engine = create_engine(url_)
    while (datetime.now() - started) < timeout:
        try:
            engine.raw_connection()
            connected = True
            break
        except Exception:
            time.sleep(1)

    return connected
