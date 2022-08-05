# Build Wagtail on sane python base image so we can deploy to AppRunner

ARG PYTHON=python:3.9.13-slim-buster
ARG PORT=8000


FROM ${PYTHON} AS install
ENV PATH=/VENV/bin:${PATH}
RUN python -m venv /VENV
WORKDIR /app
RUN pip install wagtail 
RUN wagtail start wagrun .      # creates /app/wagrun
RUN pip install -r requirements.txt


FROM ${PYTHON} AS migrate
ENV PATH=/VENV/bin:${PATH}
COPY --from=install /VENV /VENV
COPY --from=install /app /app
WORKDIR /app
RUN ./manage.py migrate
RUN DJANGO_SUPERUSER_PASSWORD=KILLME ./manage.py createsuperuser --noinput --username chris2 --email chris@v-studios.com


FROM ${PYTHON} AS run
ENV PATH=/VENV/bin:${PATH}
ENV PYTHONUNBUFFERED=1 PORT=8000
COPY --from=migrate /VENV /VENV
COPY --from=migrate /app /app
WORKDIR /app
EXPOSE 8000
CMD ./manage.py runserver 0.0.0.0:8000
