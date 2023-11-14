=============
 DEVELOPMENT
=============

Notes on getting this running locally and deployed. We start by
getting it running locally, then we send to AWS.



Run locally
===========

We build the image, and tag it for local as well as AWS consumption::

  make build

After we build, we can run. The `<start.sh>`_ is run by Docker, and
does the initial migration, and creates a password so you don't have
to; note that it uses *my* email, so you'll want to change that! Then
it does the usual Django ``runserver``. The `<Makefile>`_ makes this
easy::

  make run

This target sets flags to map the Wagtail database and media into our
local directory at `<db/>`_ and `<media/>`_ so we have persistence
across container builds and starts. We've also got a convenience
target that drops you into a shell on the container so you can look
around or do other Django management stuff::

  make bash

Both targets set a bunch of Docker and Django variables, which I'll
line-break here for readability::

   docker run -it --rm \
   -p 8000:8000 \
   -v `pwd`/db:/app/db \
   -v `pwd`/media:/app/media \
   -e DATABASE_URL="sqlite:////app/db/scale0.sqlite" \
   --name scale0 \
   scale0:dev

You can login to the Wagtail Admin UI and make changes which persist.
We only have the default a Homepage, so there's not much you can do
but change the title and publish, create a child page with title and
publish, and upload media and see them in the UI.


Deploy to AWS
=============
set your AWS Profile to get creds and region, e.g.::

  export AWS_PROFILE=scale0

Then run the `<Makefile>`_ target which builds the image from
the `<Dockerfile>`_, logs into AWS ECR, creates an ECR repo if needed,
then pushes the image to the ECR::

  make ecr_push

In this case, the repo is called ``scale0`` and the image tag is
``dev``. The repo is created outside of CloudFormation to prevent
stack roll-back with chicken-n-egg repo and image creation.

