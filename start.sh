#!/bin/sh
# Start Django, after first doing a migration and setting root user password.

./manage.py migrate
DJANGO_SUPERUSER_PASSWORD=KILLME ./manage.py createsuperuser --noinput --username chris --email chris@v-studios.com || echo "COULD NOT SET SUPERUSER, MAYBE ALREADY SET"
./manage.py runserver 0.0.0.0:8000
