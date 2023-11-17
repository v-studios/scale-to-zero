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


Build AWS Infrastructure
========================

Before we can deploy, we've got some bootstrapping to build the AWS
infrastructure. For all the AWS work, change in to the ``aws/``
directory, then set your profile so the CLI can get your creds and
region; I'm verifying my region is eu-west-3 (Paris)::

  cd aws
  export AWS_PROFILE=chris@chris+hack
  aws configure get region

We use CloudFormation nested stacks, and the main stack ``scale0-dev``
expects to see its nested components (vpc, db, apprunner) defined in
S3, not locally. So first create a bucket for these templates to be
uploaded; you'll need to create a uniquely named one::

  make create_s3

If you've already done this, or someone else already has the name,
you'll get a message like this::

  make_bucket failed: s3://scale0-cloudformation
  An error occurred (BucketAlreadyOwnedByYou) when calling the
  CreateBucket operation: Your previous request to create the named
  bucket succeeded and you already own it.

You'll need to  update the `<aws/Makefile>`_ with a new name and try again.

Now we can run a target that packages the nested stacks to our S3
bucket, and then deploys the ``scale0-dev`` cloudformation that
references them.

This is a pretty large suite. AppRunner can be finicky to get running,
and if the app startup fails, the nested stack fails, and it takes
down everything else in that deployment. It's probably best to deploy
the main stack, first with the VPC, then the DB, and findally the
AppRunner stacks; just comment and uncomment as each one is
successfully deployed.

If you change anything in the ``aws/`` directory, you'll need to
redeploy that.

If you've updated your image to be imcompatible, the CloudFormation
update may fail when it tries to launch. But we've set it to disable
rollbacks so you shold be able to fix it by deploying the image again.


Deploy Image to AWS
===================

Our app is in the main code repo dir so all the ``make`` commands are
executed there.

Set your AWS Profile to get creds and region, e.g.::

  export AWS_PROFILE=chris@chris+hack

Then run the `<Makefile>`_ target which builds the image from
the `<Dockerfile>`_, logs into AWS ECR, creates an ECR repo if needed,
then pushes the image to the ECR::

  make ecr_push

In this case, the repo is called ``scale0`` and the image tag is
``dev``. The first time this is run, it creates an ECR repo (outside
of CloudFormation) to prevent stack roll-back with chicken-n-egg repo
and image creation.

You should be able to see it going live in the App Runner Service page:
https://eu-west-3.console.aws.amazon.com/apprunner/home?region=eu-west-3#/services/dashboard?service_arn=arn%3Aaws%3Aapprunner%3Aeu-west-3%3A150806394439%3Aservice%2Fscale0-dev%2Fafbea56dc8c14dddbd81122e1a0e9781&active_tab=logs


S3 Storage and ``collectstatic``
================================

We're using S3 now for media (images, documents) and static assets
(css, js, etc) so they'll persist across App Runner death and rebirth,
just like the data in the external PostgreSQL.

In Django (and Wagtail), we need to push our statics to S3 initially,
and when we change. This is easy on a single server: just hop on and
give the command. But we can't do that when it's running in App Runner
-- there's no access to run a one-off command.

Instead, we give our Docker access to our AWS credentials and the
(hard-coded) S3 bucket name, and run it locally with a bash shell.
Then we can simply::

  ./manage.py collectstatic

This takes a little while.

Note that if we manage content on the local Docker Wagtail -- e.g.,
uploading media -- it will pollute the S3 bucket: the AppRunner
instances the PostgreSQL won't know about them, since locally we use
SQLite.

It might be smart to have a Docker run command that runs truly
locally, and another that uses S3 for our Django Djanitorial needs.
