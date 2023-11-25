======
 TODO
======

Yeah, yeah, these should be GitHub Issues.

Some are these small tasks, some may be deep rabbit holes, others may
not be do-able.

* Use Gunicorn instead of default server
* Get S3 name for Docker: aws cloudformation
  describe-stacks --stack-name scale0-dev --query "Stacks[0]"
* Should I build separate ARM (M1) and AMD (AWS) images?
* Should I switch to finch?? Will it help building multiarchitecture builds?
* Do I need the VPC public gateway?
* Do I need the routes, or does that get me to DB and S3?
* Use Django Persistent connections to attempt to avoid overwhelming
  PSQL pool?
  https://devcenter.heroku.com/articles/python-concurrency-and-database-connections
* Create service that does ``migrate`` and ``createsuperuser``,
  separate from ``runserver``, to speed startup of newly scaled App
  Runner instances.
* Set CloudWatch logs to expire in 30 days. I don't think I can do
  this because there's no log "resource" reference.

Database migration as a singleton
---------------------------------

In one client's Wagtail Prod environment we launch 2 EC2s for
redundancy (if one dies, the other will handle traffic so users
experience no outage). But when both booted for the first time from
CloudFormation and ran the Django migration, one of the two failed
because the other had already started seconds before. This caused the
entire CloudFormation deploy to roll-back. We had never seen this in
Dev or QA, because we only run one EC2 there. We had to do some
complex work to wait for CloudFormation to complete, query to find the
newest instance, then use AWS Systems Manager "Run Command" feature to
send the ``./manage.py migrate`` to its Docker container.

AWS App Runner abstracts the away EC2s, so I don't see an easy way to
remotely run a one-off command in one of its containers. The `CLI
commands
<https://docs.aws.amazon.com/cli/latest/reference/apprunner/index.html>`_
don't have anything useful. AWS Systems Manager does not seem to apply
to App Runner.

We should create a separate App Runner service, Fargate task, or
Lambda function that uses the same image, but has a different Docker
``RUN`` command that just runs the migration, with the newest code and
models in the image.


Gave up: Trigger App Runner on code commit
------------------------------------------

App Runner has a mode where it can build and deploy on commit, like
Heroku does, by defining a top-level ``apprunner.yaml`` file that
describes ``pre-build``, ``build``, ``post-build``, and ``run``
commands (and a few others). It appears to take these commands can
build a Docker image, which it then deploys and runs.

I've had little success with it, however. It runs a variant of Amazon
Linux 2, but has an ancient version of Sqlite3 that doesn't support
Django, and using AWS' EPEL repo just installs the same 3.7 version. I
even got it to download and build from source, but did not seem to be
able to get that prebuild step to make Sqlite3 available in the run
step. Does the BUILD process run in a separate container?

I was finally able to get it to almost work by doing all the build
steps in the BUILD phase (caveat: any ``cd`` commands are sticky, each
step is not atomic and isolated), but invoking ``./manage.py`` could
not find module ``django``.

We'd like to see what their custom AmazonLinux2+Python image has but
it's not publicly available; the logs show::

  [Build] Step 1/9 : FROM
  082388193175.dkr.ecr.us-east-1.amazonaws.com/awsfusionruntime-python3:3.8

After messing with this build-on-commit mode, I decided that it would
be better to separately build the Docker image on a base image that
had a working Sqlite3. This is what we do for local development now.
It's easy enough.


Custom DNS domain
-----------------

The AWS WebUI allows you to map a custom DNS domain to your App Runner
service, but it's not available yet in CloudFormation. Why does AWS
take so long to provide CloudFormation feature parity?
