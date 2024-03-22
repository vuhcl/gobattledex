set dotenv-load := true

export DATABASE_URL := env_var_or_default('DATABASE_URL', 'postgres://postgres:postgres@db:5432/postgres')

@_default:
    just --list

venv:
    pyenv virtualenv 3.12 gbd-3.12
    pyenv local gbd-3.12

bootstrap:
    just install
    just build
    just start
# just createsuperuser

# ----------------------------------------------------------------------
# DEPENDENCIES
# ----------------------------------------------------------------------

@install:
    poetry install

update:
    @just install

# ----------------------------------------------------------------------
# TESTING/TYPES
# ----------------------------------------------------------------------

test *ARGS:
    just command python3 -m pytest {{ ARGS }}

coverage:
    rm -rf htmlcov
    just command python3 -m coverage run -m pytest && python -m coverage html --skip-covered --skip-empty

types:
    just command python3 -m mypy .

# ----------------------------------------------------------------------
# DJANGO
# ----------------------------------------------------------------------

@manage *COMMAND:
    just command poetry run python3 -m manage {{ COMMAND }}

alias mm := makemigrations

makemigrations *APPS:
    @just manage makemigrations {{ APPS }}

migrate *ARGS:
    @just manage migrate {{ ARGS }}

shell-plus:
    @just manage shell_plus

createsuperuser USERNAME="admin" EMAIL="" PASSWORD="admin":
    docker compose run --rm --no-deps app /bin/bash -c 'echo "from django.contrib.auth import get_user_model; User = get_user_model(); User.objects.create_superuser('"'"'{{ USERNAME }}'"'"', '"'"'{{ EMAIL }}'"'"', '"'"'{{ PASSWORD }}'"'"') if not User.objects.filter(username='"'"'{{ USERNAME }}'"'"').exists() else None" | python3 manage.py shell'

resetuserpassword USERNAME="admin" PASSWORD="admin":
    docker compose run --rm --no-deps app /bin/bash -c 'echo "from django.contrib.auth import get_user_model; User = get_user_model(); user = User.objects.get(username='"'"''"'"'); user.set_password('"'"''"'"'); user.save()" | python3 manage.py shell'

# ----------------------------------------------------------------------
# DOCS
# ----------------------------------------------------------------------

_cog:
    cog -r docs/just.md

graph:
    just manage graph_models users \
        --exclude-models AbstractUser \
        --group-models \
        --output ./docs/applications/images/users.svg

@docs-pip-compile *ARGS:
    just pip-compile  --output-file docs/requirements.txt docs/requirements.in

@docs-upgrade:
    just docs-pip-compile --upgrade

@docs-install:
    just _install -r docs/requirements.txt

docs-serve:
    #!/usr/bin/env sh

    just _cog

    if [ -f "/.dockerenv" ]; then
        sphinx-autobuild docs docs/_build/html --host "0.0.0.0"
    else
        sphinx-autobuild docs docs/_build/html --host "localhost"
    fi

# ----------------------------------------------------------------------
# DOCKER
# ----------------------------------------------------------------------

# Build services using docker-compose
build:
    docker compose build

# Build production stack using docker-compose
build-prod:
    docker compose -f docker-compose.yml -f docker-compose.prod.yml build

# Stop and remove all containers, networks, images, and volumes
@clean:
    just down --volumes --rmi local

# Run a command within the 'app' container
command *ARGS:
    docker compose run --rm --no-deps app /bin/bash -c "{{ ARGS }}"

# Open an interactive shell within the 'app' container opens a console
console:
    docker compose run --rm --no-deps app /bin/bash

# Stop and remove all containers defined in docker-compose
down *ARGS:
    docker compose down {{ ARGS }}

# Display the logs for containers, optionally using provided arguments (e.g., --follow)
logs *ARGS:
    docker compose logs {{ ARGS }}

# Display the running containers and their statuses
ps:
    docker compose ps

# Pull the latest versions of all images defined in docker-compose
pull:
    docker compose pull

# Restart services, optionally targeting specific ones
restart *ARGS:
    docker compose restart {{ ARGS }}

# Open an interactive shell within a specified container (default: 'app')
shell *ARGS="app":
    docker compose run --rm --no-deps {{ ARGS }} /bin/bash

# Open a psql shell within the 'db' container
shell-db:
    docker compose run --rm --no-deps db psql -d {{ DATABASE_URL }}

# Start services using docker-compose, defaulting to detached mode
@start *ARGS="--detach":
    just up {{ ARGS }}

# Start the full production stack using docker-compose, defaulting to detached mode
@start-prod *ARGS="--detach":
    just up-prod {{ ARGS }}

# Stop services by calling the 'down' command
@stop:
    just down

# Continuously display the latest logs by using the --follow option, optionally targeting specific containers
@tail *ARGS:
    just logs '--follow {{ ARGS }}'

# Start services using docker-compose, with optional arguments
up *ARGS:
    docker compose up {{ ARGS }}

# Start the full production stack using docker-compose
up-prod *ARGS:
    docker compose -f docker-compose.yml -f docker-compose.prod.yml up {{ ARGS }}

# ----------------------------------------------------------------------
# UTILS
# ----------------------------------------------------------------------

envsync:
    #!/usr/bin/env python3
    from pathlib import Path

    envfile = Path('.env')
    envfile_example = Path('.env.example')

    if not envfile.exists():
        envfile.write_text(envfile_example.read_text())

    with envfile.open() as f:
        lines = [line for line in f.readlines() if not line.endswith('# envsync: ignore\n')]
        lines = [line.split('=')[0] + '=\n' if line.endswith('# envsync: no-value\n') else line for line in lines]

        lines.sort()
        envfile_example.write_text(''.join(lines))

# format justfile
fmt:
    just --fmt --unstable

# run pre-commit on all files
lint:
    pre-commit run --all-files

# ----------------------------------------------------------------------
# COPIER
# ----------------------------------------------------------------------

# create a copier answers file
copier-copy TEMPLATE_PATH DESTINATION_PATH=".":
    pipx run copier copy {{ TEMPLATE_PATH }} {{ DESTINATION_PATH }}

# update the project using a copier answers file
copier-update ANSWERS_FILE *ARGS:
    pipx run copier update --answers-file {{ ANSWERS_FILE }} {{ ARGS }}

# loop through all answers files and update the project using copier
@copier-update-all *ARGS:
    for file in `ls .copier-answers/`; do just copier-update .copier-answers/$file "{{ ARGS }}"; done
