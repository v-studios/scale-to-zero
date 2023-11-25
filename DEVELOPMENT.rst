=============
 DEVELOPMENT
=============

How to build and run the app locally, create the AWS infrastructure,
then deploy the app to AWS.

This directory has a `<Makefile>`_ to automate the boring work of
building the image and sending it to ECR. The `<aws/>`_ directory has
its own ``Makefile`` to create the AWS infrastructure.

Run locally
===========

The ``Dockerfile`` defines a multi-stage build that installs Wagtail
and a ``start.sh`` for the ``RUN`` command. The start scripts invokes
a migration and creates the superuser if it hasn't been set, then runs
the wagtail server. We can run the image locally, and also push it to
ECR for App Runner.

We build the image and tag it for local as well as AWS consumption::

  make build

Note: I'm currently using an M1 Mac but have to build an AMD image for
App Runner, but it runs plenty fast on my Mac.

After we build, we can run. The `<start.sh>`_ is run by Docker, and
does the initial migration, and creates a superuser password. Caution:
it uses *my* email so you'll want to change that! Then it does the
usual Django ``runserver``. The `<Makefile>`_ makes this easy::

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


Deploy Image to AWS
===================

Before we can build our AWS infrastructure, we have to make an image
available to it in ECR, or else the stacks will fail and roll back. We
have an chicken-and-egg problem which requires us to create the ECR
and provide an image before we trying to create the infrastructure. So
we'll do that first; just realize that the ECR is not controlled by
the AWS CloudFormation stacks.

Our app is in the main code repo dir so all the ``make`` commands are
executed there.

Set your AWS Profile to get creds and region, e.g.::

  export AWS_PROFILE=chris@chris+hack

Then run the `<Makefile>`_ target which builds the image from
the `<Dockerfile>`_, logs into AWS ECR, creates an ECR repo if needed,
then pushes the image to the ECR::

  make ecr_push

In this case, the repo is called ``scale0`` and the image tag is
``dev``. The first time this is run, it creates the ECR repo (outside
of CloudFormation).

Once the AWS infrastructure is live, after pushing a new image to ECR,
it takes App Runner about 5 minutes to download, launch, check health,
and shift traffic to the new instance.


Build AWS Infrastructure
========================

Once the image is available in the ECR, we can build the AWS
infrastructure. We'll build a VPC, subnets, database, S3, App Runner,
and everything the service needs using CloudFormation. Everything is
in the ``aws/`` directory. It uses nested stacks for VPC, RDS, S3, and App
Runner; the top level stack passes outputs from one stack to the next
which uses them. Currently there is only a ``wagrun-dev.yaml`` top
level stack.

The ``Makefile`` has a default target that packages the sub-stack files,
then deploys the parent ``scale0-dev.yaml`` stack with CloudFormation.

For all the AWS work, change in to the ``aws/`` directory, then set
your profile so the CLI can get your creds and region; below, I verify
my region is eu-west-3 (Paris)::

  cd aws
  export AWS_PROFILE=chris@chris+hack
  aws configure get region

We use CloudFormation nested stacks. The main stack ``scale0-dev``
expects to see its nested components (vpc, db, s3, apprunner) defined
in S3, not on local disk. So first create a bucket for these templates
to be uploaded; you'll need to create a uniquely named one::

  make create_s3

If you've already done this, or someone else already has the name,
you'll get a message like this::

  make_bucket failed: s3://scale0-cloudformation
  An error occurred (BucketAlreadyOwnedByYou) when calling the
  CreateBucket operation: Your previous request to create the named
  bucket succeeded and you already own it.

You'll need to update the `<aws/Makefile>`_ with a new name and try
again.

Now we can run a target that packages the nested stacks to our S3
bucket, and then deploys the ``scale0-dev`` cloudformation that
references them::

  make deploy

This is a non-trivial suite. AppRunner can be finicky to get running,
and if the app startup fails, the nested stack fails, and it takes
down everything else it's built in that deployment. I've set the
``--disable-rollback`` flag in the ``Makefile`` to try and prevent
tearing down successfully-deployed infrastructure. It may be best to
deploy the main stack, first with the VPC, then the DB, then S3, and
finally the AppRunner stacks; just comment and uncomment as each one
is successfully deployed.

If you change anything in the ``aws/`` directory, you'll need to
redeploy that.

Monitoring, Logs
================

Once running, you can look at the scaling for RDS and App Runner.

Logs are critical for debugging. The AWS console for App Runner shows
almost-live deployment logs, and at the bottom, logs for the app
itself. I found the latter critical when debugging a wrong-platform
image.

* App Runner Events:
  CloudWatch > Log groups > /aws/apprunner/scale0-dev/$UUID/service > events
* Application Logs:
  CloudWatch > Log groups > /aws/apprunner/scale0-dev/$UUID/application : instance/$ID

Click the links to the CloudWatch logs to dig deeper, especially to
debug launch problems.

S3 Storage and ``collectstatic``
================================

We're using S3 now for media (images, documents) and static assets
(e.g., css, js) so they'll persist across App Runner death and
rebirth, just like the data in the external PostgreSQL.

In Django (and Wagtail), we need to push our statics to S3 initially
and when we change the code. This is easy on a single server: just hop
on and give the command. But we can't do that when it's running in App
Runner -- there's no access to run a one-off command.

Instead, we give our Docker access to our AWS credentials and the
(hard-coded) S3 bucket name, and run it locally with a bash shell.
There's a separate target for that, so we can invoke that::

  make s3_bash

then in the container with S3 access, run the Django command::

  root@70f347c6414c:/app# ./manage.py  collectstatic -v3
  ...
  You have requested to collect static files at the destination
  location as specified in your settings.
  This will overwrite existing files!
  Are you sure you want to do this?
  Type 'yes' to continue, or 'no' to cancel: yes
  Deleting 'js/scale0.js'
  Copying '/app/scale0/static/js/scale0.js'
  ...
  Deleting 'admin/img/gis/move_vertex_off.svg'
  Copying '/VENV/lib/python3.12/site-packages/django/contrib/admin/static/admin/img/gis/move_vertex_off.svg'
  223 static files copied.

This takes a few minutes.

Note that if we run Wagtail and manage content on Docker with S3
access -- e.g., uploading media -- it will pollute the S3 bucket: App
Runner's PostgreSQL database won't know about them, since we use
SQLite for Docker.
