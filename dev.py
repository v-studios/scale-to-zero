from .base import *

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

# If DATABASE_URL is defined, configure from that:
#    DATABASE_URL="sqlite:////tmp/db.sqlite3"
#    DATABASE_URL="postgres://USER:PASSWORD@HOST:PORT/NAME"
print("###### DEV.PY goes searching for database")
import dj_database_url
database_url = os.environ.get("DATABASE_URL")  # all pieces in one variable, but not parsing correctly
database_host = os.environ.get("DATABASE_HOST")
database_port = os.environ.get("DATABASE_PORT")
database_name = os.environ.get("DATABASE_NAME")
database_user = os.environ.get("DATABASE_USER")
database_password = os.environ.get("DATABASE_PASSWORD")
print(f"## {database_url=}")
print(f"## {database_host=} {database_port=} {database_name=} {database_user=} {database_password=}")
# I think dj_database_url isn't parsing DATABASE_URL properly, if it thinks NAME is the entire string:
#   'wagrundev.cluster-cwdazoayirv4.us-east-1.rds.amazonaws.com:5432/wagrundev' (73 characters)
#   is longer than PostgreSQL's limit of 63 characters
## database_url='postgres://dbuser@ChangeMe/wagrundev.cluster-cwdazoayirv4.us-east-1.rds.amazonaws.com:5432/wagrundev'
## Is that the right shape?
if database_url:
    DATABASES['default'] = dj_database_url.config(conn_max_age=600)
    print(f"{DATABASES=}")
elif database_host:
    DATABASES['default'] = {
        "ENGINE": "django.db.backends.postgresql",
        "HOST": database_host,
        "PORT": database_port,
        "NAME": database_name,
        "USER": database_user,
        "PASSWORD": database_password
        # Do I want OPTIONS to specify `timeout` for Serverless Aurora?
    }

try:
    from .local import *
except ImportError:
    pass
