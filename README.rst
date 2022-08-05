======================
 Wagtail on AppRunner
======================

AppRunner is ideally suited for running pure HTTP apps that don't need
features Fargate provides. The config is much simpler, and it
autoscales based on demand and includes its own ALB. It can now access
things in a VPC, so we can have our app talk to an RDS (or Aurora
serverless) DB. Both can scale to zero to save money on sites that
aren't used 24x7.

We want to deploy Wagtail CMS with a PostgreSQL DB. Start with 24x7
RDS to get the VPC worked out, then try scale-to-zero Aurora.

See:

* Excellent blog post comparing simplicity and cost: `Fargate vs. App
  Runner <https://cloudonaut.io/fargate-vs-apprunner/>`_
* Live Coding video: `Migrating from ECS and Fargate to AWS App Runner
  <https://www.youtube.com/watch?v=ABvx7radhw4>`_
* AWS AppRunner `FAQs <https://aws.amazon.com/apprunner/faqs/>`_

Unfortunately, it is NOT FedRAMPed at this time.

Using apprunner.yaml
====================

We can have App Runner build and deploy on commit, like Heroku does,
by defining an ``apprunner.yaml`` file that describes ``pre-build``,
``build``, ``post-build``, and ``run`` commands (and a few others). It
appears to take these commands and build a Docker image, which it then
deploys and runs.

I've had no success with, it fails mysteriously, and I don't have
visiblity to debug it. When it starts to run (maybe migrate?), it
complains about a too-old sqlite3::

  08-04-2022 07:21:27 PM sqlite3.NotSupportedError: deterministic=True requires SQLite 3.8.3 or higher

and the deploy fails. 

I've revised it to only do apt-get install in the pre-build, but it
appears this may not be a Debian based system, like DockerHub's python:3.8::

  [Build] [91m/bin/sh: apt-get: command not found
  [Build]  ---> Running in 530035770d6b
  [Build] Step 4/9 : RUN apt-get install -y sqlite3

AWS is using AmazonLinux2:

  This image is based on the Amazon Linux Docker image and contains
the runtime package for a version of Python and some tools and popular
dependency packages.

When I run that I see that it does have an ancient version of Sqlitte3::

  % docker run -it --rm amazonlinux
  bash-4.2# sqlite3 --version
  3.7.17 2013-05-20 00:56:22 118a3b35693b134d56ebd780123b7fd6f1497668

But I cannot get a newer version::

  bash-4.2# yum update -y sqlite
  Loaded plugins: ovl, priorities
  No packages marked for update

It appears I have to add a repo pointing at a modern verions. Adding
the ``epel`` repo and trying to do an install or update still gives me
sqlite 3.7.

Trying to install with Sqlite site's .zip shows my AL2 doesn't have
``zip``. Trying to install into my AL2 says I need libc.so.6 and
others.

Smells like a :squirrel:-from-hell.

VPC for RDS
===========

We'll need a VPC for RDS and it has to export its subnets and security
groups so we can reference them in the AppRunner config. We do that
with ``vpc.yaml``.
