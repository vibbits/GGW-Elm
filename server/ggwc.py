"""
GGW server administration console command.
This is intended to be run for administration tasks such as
updating the database schema, adding an admin user,
adding an identity provider, etc.
"""

from typing import Tuple, Optional

import sys
from pathlib import Path
from datetime import datetime
import csv
import click
import httpx
from Bio import SeqIO
from sqlalchemy.exc import SQLAlchemyError

from app.model import Vector, Annotation, Reference, Qualifier, Feature

from app.database import SessionLocal
from app.level import VectorLevel
from app import model, crud, oidc, schemas


@click.group()
def cli():
    "Top-level CLI"


@cli.command()
@click.option("--iss", default=1, help="identity provider")
@click.option("--sub", required=True, help="subject")
@click.argument("name")
def create_admin(iss, sub, name):
    "Create a new admin user"
    with SessionLocal() as database:
        if (provider := crud.get_provider_by_id(database, provider_id=iss)) is None:
            click.echo(f"No identity provider with id={iss}", err=True)
            return

        user = schemas.UserCreate(name=name, role="admin", iss=provider.issuer, sub=sub)
        crud.create_user(database, user)
        click.echo(f'Admin ({name}) created with issuer "{provider.name}"')


@cli.command()
@click.option("--issuer", help="Base OpenID Connect issuer URL")
@click.option("--clientid", help="Client identifier issued by the identity provider")
@click.option("--secret", help="Client secret issued by the identity provider")
@click.option("--name", help="Human readable name of this provider")
def add_identity_provider(name, issuer, clientid, secret):
    "Add a new identity provider"
    try:
        response = httpx.get(f"{issuer}/.well-known/openid-configuration")
        if response.status_code != 200:
            click.echo(
                f"Could not query OpenID configuration from issuer: {issuer}", err=True
            )
            return
    except httpx.ConnectError:
        click.echo(f"Could not connect to OpenID provider: {issuer}")
        return

    with SessionLocal() as database:
        try:
            provider = model.IdentityProvider(
                name=name, issuer=issuer, clientid=clientid, secret=secret
            )
            database.add(provider)
            database.commit()
        except SQLAlchemyError as err:
            database.rollback()
            click.echo(
                f"Could not add provider: {err.orig}", err=True
            )  # pylint: disable=no-member
        else:
            click.echo(f"Added identity provider: {name}")


@cli.group()
def show():
    "Sub-command to display info"


@show.command()
def providers():
    "Show identity providers"
    with SessionLocal() as database:
        for provider in crud.get_identity_providers(database):
            click.echo(f"{provider.id}: {provider.name} | {provider.issuer}")


@show.command()
@click.option("--iss", default=1, help="identity provider")
def login(iss):
    "Show login urls"
    with SessionLocal() as database:
        if (provider := crud.get_provider_by_id(database, iss)) is None:
            click.echo(f"No identity provider with id={iss}", err=True)
            return

        try:
            config = httpx.get(
                f"{provider.issuer}/.well-known/openid-configuration"
            ).json()
        except httpx.RequestError as err:
            click.echo(f"Error while requesting {err.request.url!r}")
        except httpx.HTTPStatusError as err:
            click.echo(
                f"Error response {err.response.status_code} while requesting {err.request.url!r}"
            )
        else:
            click.echo(oidc.login_url(config["authorization_endpoint"], provider))


def vector_level(g_number: str) -> Optional[VectorLevel]:
    "Converts part of the MP-GX-name to a VectorLevel"
    if g_number == "GB":
        vec_level = VectorLevel.BACKBONE
    elif g_number == "G0":
        vec_level = VectorLevel.LEVEL0
    elif g_number == "G1":
        vec_level = VectorLevel.LEVEL1
    else:
        vec_level = None
    return vec_level


def extract_loc(loc: str) -> Tuple[Optional[VectorLevel], int]:
    "Splits the MP-GX-number and returns the VectorLevel and the numberpart"
    split = loc.split("-")
    return (vector_level(split[1]), int(split[2]))


@cli.command()
@click.argument("csv_path")
@click.argument("gbk_path")
@click.argument("user")
def import0(csv_path, gbk_path, user):
    """
    Extracts the vector information from a csv file and seperate genbank files
    and adds them to an sqlite database.
    """
    with SessionLocal() as database:
        # Lookup user
        if (
            db_user := database.query(model.User).filter(model.User.sub == user).first()
        ) is None:
            click.echo(f"No user with subject: {user}")
            sys.exit(1)

    print(f"Looked up user: {db_user}")
    # read the cvs-file
    csv_content = []

    with open(csv_path) as csv_file:
        csv_reader = csv.DictReader(csv_file)
        for item in csv_reader:
            csv_content.append(item)
    csv_file.close()

    files_to_read = [
        (i, entry["Name Genbank file"]) for i, entry in enumerate(csv_content)
    ]

    vec_list = []
    child_ids_list = []

    for i, gbk_file in files_to_read:
        # Create vector and fill in data from csv file
        vec = Vector()
        loc = extract_loc(csv_content[i]["MP-G- number"])
        vec.location = loc[1]
        vec.name = csv_content[i]["Plasmid name"]
        vec.bacterial_strain = csv_content[i]["Bacterial strain"]
        vec.responsible = csv_content[i]["Responsible"]
        vec.group = csv_content[i]["Group"]
        vec.level = loc[0]
        vec.bsa1_overhang = csv_content[i]["BsaI overhang"]
        vec.selection = csv_content[i]["Selection"]
        vec.cloning_technique = csv_content[i]["DNA synthesis or PCR?"]
        vec.bsmb1_overhang = csv_content[i]["BsmBI overhang"]
        vec.is_BsmB1_free = csv_content[i]["BsmBI free? (Yes/No)"]
        vec.notes = csv_content[i]["Notes"]
        vec.REase_digest = csv_content[i]["REase digest"]
        try:
            vec.date = datetime.strptime(csv_content[i]["Date (extra)"], "%d/%m/%Y")
        except ValueError as err:
            print(f"While extracing {gbk_file}, error parsing date: {err}")
            vec.date = None
        vec.gateway_site = csv_content[i]["Gateway site"]
        vec.vector_type = csv_content[i]["Vector type (MP-G2-)"]
        vec.children = []

        child_ids_list.append(
            [
                int(id) if id != "" else None
                for id in csv_content[i]["Children ID"]
                .replace("[", "")
                .replace("]", "")
                .split(",")
            ]
        )

        # Adding the admin-user 'ggw' list of users
        vec.users = [db_user]

        # Reading the sequence from the genbank file
        gbk_file_path = Path(gbk_path) / Path(gbk_file)
        record = SeqIO.read(gbk_file_path, "genbank")
        vec.sequence = str(record.seq)

        # Getting the annotations
        annotations = []
        references = []
        for key, value in record.annotations.items():
            # All annotations are strings, integers or list of them
            # but references are a special case.
            # References are objects that can be deconstructed to
            # an author and a title, both strings.
            if key == "references":
                for reference in record.annotations["references"]:
                    references.append(
                        Reference(authors=reference.authors, title=reference.title)
                    )
            else:
                annotations.append(Annotation(key=key, value=str(value)))

        vec.annotations = annotations
        vec.references = references

        # Getting the features:
        features = []
        for feature in record.features:
            # Getting the qualifiers of each feature

            new_qualifiers = []
            for key, value in feature.qualifiers.items():
                new_qualifiers.append(Qualifier(key=key, value=str(value)))
            features.append(
                Feature(
                    type=feature.type,
                    qualifiers=new_qualifiers,
                    start_pos=feature.location.nofuzzy_start,
                    end_pos=feature.location.nofuzzy_end,
                    strand=feature.location.strand,
                )
            )

        vec.features = features

        # Append to vec_list
        vec_list.append(vec)

    with SessionLocal() as database:
        for vec in vec_list:
            # Removing child items
            vec.children = []

            # Convert to dict
            new_vec = vars(vec)
            # Make a VectorInDB object (also has the sequence!)
            vec_in_db = schemas.VectorInDB(**new_vec)
            if (
                crud.add_vector(database=database, vector=vec_in_db, user=db_user)
                is not None
            ):
                click.echo(f"Vector '{vec.name}' added.")

    vec_list2 = []

    with SessionLocal() as db:
        vec_list2 = crud.get_all_vectors(database=db)

    for i, vec in enumerate(vec_list2):
        if vec.level == VectorLevel.LEVEL1:
            with SessionLocal() as database:
                for child_id in child_ids_list[i]:

                    crud.add_vector_hierarchy(
                        database=database, child_id=child_id, parent_id=vec.id
                    )


if __name__ == "__main__":
    cli()
