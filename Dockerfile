# Build Wagtail on sane python base image so we can deploy to AppRunner
# python-3.12.0 first released 2023-10-02.
# Debian 11 Bullseye seems safer than the new 12 Bookworm.

ARG PYTHON=python:3.12.0-slim-bullseye
ARG PORT=8000
ARG OP_ENV=dev

FROM ${PYTHON} AS install
ENV PATH=/VENV/bin:${PATH}
RUN python -m venv /VENV
WORKDIR /app
RUN pip install wagtail         # latest version
RUN wagtail start scale0 .      # creates /app/scale0
RUN pip install -r requirements.txt # created by "wagtail start"
RUN pip install dj-database-url psycopg2-binary django-debug-toolbar django-storages boto3

FROM ${PYTHON} AS run
ENV PATH=/VENV/bin:${PATH}
ENV PYTHONUNBUFFERED=1 PORT=8000
ENV DATABASE_URL=${DATABASE_URL}
ENV AWS_STORAGE_BUCKET_NAME=${AWS_STORAGE_BUCKET_NAME}
COPY --from=install /VENV /VENV
COPY --from=install /app /app
WORKDIR /app
COPY dev.py   ./scale0/settings/
COPY start.sh ./
EXPOSE 8000
CMD ./start.sh
