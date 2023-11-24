from .base import *

import dj_database_url

# SECURITY WARNING: don't run with debug turned on in production!
DEBUG = True

# SECURITY WARNING: keep the secret key used in production secret!
SECRET_KEY = "django-insecure-!jr0je-3w+3i6as15ob(kpnax(9yn9b&mmlk3z_uc+y1vhq@8f"

# SECURITY WARNING: define the correct hosts in production!
ALLOWED_HOSTS = ["*"]

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"


# Fix to allow App Runner origins to submit forms
CSRF_TRUSTED_ORIGINS=[
    'https://*.us-east-1.awsapprunner.com',
    'https://*.eu-west-3.awsapprunner.com',
]

bucket_name = os.environ.get("AWS_STORAGE_BUCKET_NAME")
print(f"#### DEV.PY STORAGES: {bucket_name=}")
if bucket_name:
    print(f"#### DEV.PY STORAGES configuring STORAGES for S3...")
    INSTALLED_APPS.append("storages")  # media/ and static/ in S3
    del STATICFILES_STORAGE            # conflicts with STORAGES
    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.s3.S3Storage",
            # Default behavior uses non-public objects with Presigned URLs.
            "OPTIONS": {
                "bucket_name": bucket_name,
            },
        },
        "staticfiles": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": {
                "bucket_name": bucket_name,
            },
    },
}


# Configure from DATABASE_URL:
# * "sqlite:////tmp/db.sqlite3"
# * "postgres://USER:PASSWORD@HOST:PORT/NAME"
database_url = os.environ.get("DATABASE_URL")  # all pieces in one string
if database_url:
    print(f"#### DEV.PY DB using {database_url=}")
    DATABASES['default'] = dj_database_url.config(conn_max_age=600)
else:
    print(f"#### DEV.PY DB ERROR could not find database settings")
print(f"#### DEV.PY DB {DATABASES=}")

try:
    from .local import *
except ImportError:
    pass
