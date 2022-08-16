====================================================
 Wagtail on App Runner with Aurora Serverless v1 DB
====================================================

AWS `App Runner <https://aws.amazon.com/apprunner/>`_ is ideally
suited for running pure HTTP apps that don't need features Fargate
provides. The config is much simpler, it auto-scales based on demand,
and it includes its own load balancer. As of February 2022, it can
access things in a VPC, so we can have our app talk to an RDS DB
including Aurora serverless. Both can scale to zero to save money on
sites that aren't used 24x7.

Here, we deploy a stock Wagtail CMS with a PostgreSQL DB. See:

* Excellent blog post comparing simplicity and cost: `Fargate vs. App
  Runner <https://cloudonaut.io/fargate-vs-apprunner/>`_
* Live Coding video: `Migrating from ECS and Fargate to AWS App Runner
  <https://www.youtube.com/watch?v=ABvx7radhw4>`_
* AWS App Runner `FAQs <https://aws.amazon.com/apprunner/faqs/>`_

Unfortunately, App Runner it is NOT FedRAMPed at this time, so we
won't be able to use it for NASA yet.

Gave Up on Source Code Triggers
===============================

App Runner has a mode where it can build and deploy on commit, like
Heroku does, by defining a top-level ``apprunner.yaml`` file that
describes ``pre-build``, ``build``, ``post-build``, and ``run``
commands (and a few others). It appears to take these commands and
build a Docker image, which it then deploys and runs.

I've had little success with it, however. It runs a variant of Amazon
Linux 2, but has an ancient version of Sqlite3 that doesn't support
Django, and using AWS' EPEL repo just installs the same 3.7 version. I
even got it to download and build from source, but did not seem to be
able to get that prebuild step to make Sqlite3 available in the run
step. Does the BUILD process run in a separate container?

I was finally able to get it to almost work by doing all the build
steps in the BUILD phase (caveat: any ``cd`` commands are sticky, each
step is not atomic and isolated), but invoking ``./manage.py`` could not find module ``django``.

We'd like to see what their custom AmazonLinux2+Python image has but
it's not publicly available; the logs show::

  [Build] Step 1/9 : FROM 082388193175.dkr.ecr.us-east-1.amazonaws.com/awsfusionruntime-python3:3.8

After messing with this build-on-commit mode, I decided that it would
be better to build separately a Docker image on a base image that had
a working Sqlite3, which the rest of this doc uses.


Docker-based Deployment: Manual
===============================

I created a multi-stage Dockerfile that installs Wagtail, with a
``start.sh`` for the ``RUN`` that migrates and runs wagtail. Now I
want to deploy it to App Runner.

Initially, in the App Runner console I created a service from ECR and told it to
create the required IAM Role allowing App Runner to access ECR.

It deployed and runs it, I can see it in the provided URL.

However when I try to login it complains::

  Forbidden (403)
  CSRF verification failed. Request aborted.
  Origin checking failed - https://2mmyr8wk23.us-east-1.awsapprunner.com does not match any trusted origins.

I didn't see this when run locally, but I fixed it in AWS by adding a
custom ``dev.py`` settings file that Docker uses, and this works::

 CSRF_TRUSTED_ORIGINS=['https://*.us-east-1.awsapprunner.com']

Hitting the Deploy button again grabs the latest image with the same
name:tag; it takes about 5 minutes to become live.

The ``Makefile`` has a default target that builds, tags, and uploads
an image to ECR called ``wagrun``. If no ECR exists, it creates one.
Images are tagged based on environment: ``:dev``, ``:qa``, ``:prod``.
We ensure that the CloudFormation top level stacks (e.g.,
``dev.yaml``) specify the correct ECR.


Docker-based Deployment: Automate with CloudFormation
=====================================================

We'll build a VPC, subnets, and everything the service needs using
CloudFormation, everything is in the ``aws/`` directory. It uses
nested stacks for VPC, RDS, and App Runner; the top level stack passes
outputs from one stack to the next which uses them. Currently there is
only a ``wagrun-dev.yaml`` top level stack.

The ``Makefile`` has a default target that copies the sub-stack files,
then deploys the parent ``dev.yaml`` stack with CloudFormation.

The overall architecture looks like this:

.. image:: wagrun-arch.png
           :width: 100%


VPC for RDS
-----------

We'll need a VPC for RDS and it has to export its subnets and security
groups so we can reference them in the App Runner config. We do that
with ``vpc.yaml``. We create "public" subnets to avoid the cost of NAT
Gateway, and deploy the RDS and App Runner's "VPC Connector" there.

We do not define the ECR in this CloudFormation because when the App
Runner service launches, it needs to be able to find the image in the
ECR; when it cannot, it rolls back the entire stack. That's why we
created the ECR in the top-level Makefile, so we could have an image
already installed. This allows us to build, tag, and push images
independent of the AWS nested stacks -- for all environments.

Django ``DATABASE_URL`` did not work for me
-------------------------------------------

We want to be able to set the Database based on our environment with
runtime environment variables, per the Twelve-Factor App pattern.
Django has an add-on `dj-database-url
<https://pypi.org/project/dj-database-url/>`_ which allows us to
specify all the parts of the database connection in one variable,
like::

  DATABASE_URL="sqlite:////tmp/db.sqlite3"
  DATABASE_URL="postgres://dbuser@ChangeMe/wagrundev.cluster-cwdazoayirv4.us-east-1.rds.amazonaws.com:5432/wagrundev"

I was able to get this to run locally like::

  docker run -it --rm -p 8000:8000 -e DATABASE_URL="sqlite:////tmp/db.sqlite3" wagrun:dev

But when I moved to PostgreSQL on App Runner with::

    DATABASE_URL="postgres://dbuser:ChangeMe@wagrun-dev-db-1zu57g3uqx51-database-ghv5kxp65q1z.cluster-cwdazoayirv4.us-east-1.rds.amazonaws.com:5432/wagrun"

it seemed to parse badly and PostgreSQL complained that the database
"name" was longer than the permitted 63 characters.

I've now gone back to setting each DB parameter separately.

RDS Aurora Serverless v1
------------------------

Our goal is to reduce cost by scaling to zero. AWS RDS Aurora
Serverless v1 does this natively: if no connections are seen for some
time, it spins down the container. When a connection comes in, it
spins it back up.

We create our Aurora DB in the ``db.yaml`` file, and specify a
5-minute pause timeout::

  ScalingConfiguration:
    AutoPause: true
    MaxCapacity: 4
    MinCapacity: 2
    SecondsUntilAutoPause: 300


Connect App Runner to RDS in VPC
================================

There are 2 public subnets in the VPC, and both App Runner and RDS are
there there. Initially, App Runner was not able to connect to the DB
and the image deployment and App Runner appeared to roll back to the
last known good image, which was actually one running with Sqlite3.
These articles helped:

* https://docs.aws.amazon.com/apprunner/latest/dg/network-vpc.html
* https://aws.amazon.com/blogs/aws/new-for-app-runner-vpc-support/

The ``vpc.yaml`` now defines two security groups. The ``apprunner-sg``
is simply used to mark the App Runner service, and the ``db-sg``
specifies that any resource having that SG is allowed to access the
RDS DB on the PostgreSQL port.

I validated this by launching an Ubuntu EC2 into a subnet in the VPC,
added the App Runner SecurityGroup to it, and was able to access the
DB::

  $ psql -h wagrundev.cluster-cwdazoayirv4.us-east-1.rds.amazonaws.com -U dbuser  -d wagrundev
  Password for user dbuser:
  psql (14.3 (Ubuntu 14.3-0ubuntu0.22.04.1), server 11.13)
  wagrundev=> \dt
  Did not find any relations.
  wagrundev=>

However, the connection seemed to timeout at first. Perhaps it did not
wait long enough for the Aurora Serverless DB to start up.

Now that connectivity is working, and our App Runner service has the
marker SecurityGroup, I forced a relaunch of Django with the AWS WebUI
DEPLOY button.

On the EC2, I hit ``\dt`` and watched as wagtail tables were created!
I went to the app's link (NASA Firewall currently blocks App Runner
URLs) and edit the home page title which is displayed in the browser
title header. It shows up there. Back on EC2 I query the DB to ensure
it stuck::

  ...
  3 | 00010001 |     2 |        0 | Home (edited) | home | t    | f                       | /home/   |           | f             |                    |            |           | f       |               2 |          | f      | 2022-08-12 20:32:27.371235+00 | 2022-08-12 20:32:27.442296+00 |                2 | 2022-08-12 20:32:27.442296+00 | Home (edited) |           |              | a4fd16b4-8098-418f-bcfd-dec1db4df038 |         1 |

Notice ``Home (edited)`` twice above. Huzzah!

Verifying Scale to Zero
=======================

We should be able to "scale to zero" both the App Runner service and
its Aurora Serverless DB to save AWS costs.

App Runner
----------

App Runner's CloudFormation allows you to specify the ARN of a
pre-defined AutoScalingConfiguration, but there doesn't appear to be a
way to create this configuration with CloudFormation yet. When I tried
the CLI and WebUI, I found I could not set a minimum of 0, it had to
be 1 or more. This suggests that this config is not how to request
scale-to-zero.

We have to ensure that Wagtail doesn't leave a persistent connection
to the database. In the `Django Databases docs
<https://docs.djangoproject.com/en/4.1/ref/databases/>`_ it says:

  Persistent connections avoid the overhead of reestablishing a
  connection to the database in each request. They’re controlled by
  the CONN_MAX_AGE parameter which defines the maximum lifetime of a
  connection.

  The default value is 0, preserving the historical behavior of
  closing the database connection at the end of each request. To
  enable persistent connections, set CONN_MAX_AGE to a positive
  integer of seconds.

  [...] The development server creates a new thread for each request
  it handles, negating the effect of persistent connections. Don’t
  enable them during development.

We're not specifying ``CONN_MAX_AGE`` so should not have persistent
connections; we're also currently running the development server,
which does not persist.

The App Runner "Metrics" tab shows at the bottom the number of "Active
instances; the graph shoes zero at 2022-08-12 19:00, one between 20:00
and 21:00, then back to zero at 22:00; zooming into the 12th shows it
spiking more granularly:

.. image:: active-instances-week.png
           :height: 200
.. image:: active-instances-day.png
           :height: 200

So we can conclude App Runner is scaling to zero as desired.

Aurora Serverless
-----------------

Presumably the Database will pause when there are no active
connections for a while, after our 5 minute configuration. Under the
Databases "Monitoring" tab we can see DB Connections and Serverless
Database Capacity:

.. image:: db-connections.png
           :height: 200
.. image:: db-capacity.png
           :height: 200

TODO
====

Some ideas to explore if we want to pursue this.

DB timeout
----------

If Wagtail fails to connect to the database because the DB has paused,
we may have to increase the time it waits for a valid connection.
Django Database configuration allows you to specify ``OPTIONS``. For
`PostgreSQL
<https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-PARAMKEYWORDS>`_,
we would set ``connect_timeout``. So we might have something like::

      DATABASES['default'] = {
          "ENGINE": "django.db.backends.postgresql",
          "HOST": database_host,
          "PORT": database_port,
          "NAME": database_name,
          "USER": database_user,
          "PASSWORD": database_password,
          "OPTIONS": {
                  "connect_timeout": 42,
          },
      }

S3 storage
----------

For a real applications, we need persistence for our media and assets.
As we do with TTT2 and ALPS, we should create an S3 bucket, in a
CloudFormation template ``s3.yaml``. Then add the correct package and
configuration settings to our Django config. We probably will have to
create an S3 VPC Endpoint, like we did for OCREVA which had Lambdas in
a VPC.


TTT2, NCRP, ALPS
----------------

This stock Wagtail deployment was designed to explore App Runner and
Aurora Serverless, not to be a full Wagtail app.

We'd like to get our non-government Wagtail applications deployed in
this "scale to zero" manner.

ALPS cannot use this because App Runner is not FedRAMP certified. We
should reach out to our EAST2 AWS support people to see if they have
an estimate, even if it's not a commitment. Of course there's no
reason why we couldn't deploy it as a test on App Runner in the WSO1
Dev account we're using now.

We should ask the folks running WSO2 if they will allow App Runner
when it is FedRAMPed. We have found that many FedRAMPed services are
disabled for us by IAM Permission restrictions.

MOAR subnets
------------

Some docs I have read recommend using 3 different Availability Zones,
instead of the 2 we typically use. That makes sense: it provides more
resilience.

Just update the ``vpc.yaml`` CloudFormation to create another subnet
and output it for consumption by the other sub-stacks.
