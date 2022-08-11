# Build Wagtail on sane python base image so we can deploy to AppRunner

ARG PYTHON=python:3.9.13-slim-buster
ARG PORT=8000
ARG OP_ENV=dev

FROM ${PYTHON} AS install
ENV PATH=/VENV/bin:${PATH}
RUN python -m venv /VENV
WORKDIR /app
RUN pip install wagtail 
RUN wagtail start wagrun .      # creates /app/wagrun
RUN pip install -r requirements.txt
RUN pip install dj-database-url psycopg2-binary

FROM ${PYTHON} AS migrate
ENV PATH=/VENV/bin:${PATH}
COPY --from=install /VENV /VENV
COPY --from=install /app /app
WORKDIR /app

FROM ${PYTHON} AS run
ENV PATH=/VENV/bin:${PATH}
ENV PYTHONUNBUFFERED=1 PORT=8000
ENV DATABASE_URL=${DATABASE_URL}
COPY --from=migrate /VENV /VENV
COPY --from=migrate /app /app
WORKDIR /app
COPY dev.py   ./wagrun/settings/
COPY start.sh ./
EXPOSE 8000
CMD ./start.sh
