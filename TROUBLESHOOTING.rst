=================
 Troubleshooting
=================

Logs
====

The AWS App Runner web console shows some logs from Cloud Watch.

The "App Runner event logs" like::

  [AppRunner] Successfully copied the image from ECR.
  [AppRunner] Provisioning instances and deploying image for publicly accessible service.
  [AppRunner] Performing health check on port '8000'.
  [AppRunner] Your application stopped or failed to start. See logs for more information.  Container exit code: 1

are in::

  CloudWatch > Log groups > /aws/apprunner/scale0-dev/$UUID/service > events

The "Deployment Logs" like::

  11-14-2023 04:25:35 PM [AppRunner] Starting to pull your application image.
  11-14-2023 04:28:41 PM [AppRunner] Failed to deploy your application image.

are in::

  CloudWatch > Log groups > /aws/apprunner/scale0-dev/$UUID/service > deployment

The console also linnks to the application's logs in Cloudwatch::

  /aws/apprunner/scale0-dev/$UUID/application/...

and under there, are logs for each instance, like::

  instance/$InstanceID


App Runner: Service doesn't launch -- wrong image architecture
==============================================================

Watched the App Runner console and saw::

  2023-11-14 16:07:04 UTC+0100 Service CREATE_FAILED Resource handler
  returned message: "Your service failed to create. Review the
  application logs to find the source of error and retry."

Event Logs in the console::

  11-14-2023 04:26:00 PM [AppRunner] Pulling image 150806394439.dkr.ecr.eu-west-3.amazonaws.com/scale0 from ECR repository.
  11-14-2023 04:27:08 PM [AppRunner] Successfully copied the image from ECR.
  11-14-2023 04:27:19 PM [AppRunner] Provisioning instances and deploying image for publicly accessible service.
  11-14-2023 04:27:29 PM [AppRunner] Performing health check on port '8000'.
  [waiting...]d
  11-14-2023 04:28:23 PM [AppRunner] Your application stopped or failed to start. See logs for more information.  Container exit code: 1

CloudWatch > Log Groups >
/aws/apprunner/scale0-dev/$UUID/application/instance/$ID::

  exec /bin/sh: exec format error

I suspected the image I built on my M1 Mac was for ARM but App Runner
needed AMD. Use ``docker image inspect scale0:dev`` and check the
architecture of the image::

        "Architecture": "arm64",

That's Apple silicon. We need AMD/Intel/X86. I changed the ``build``
target in the ``Makefile`` to specify the AMD architecture::

 docker build --platform linux/amd64 --progress=plain -t ${APP_NAME}:${OP_ENV} .
 docker build --platform linux/amd64 --progress=plain -t ${ECR_REG_REPO_TAG} .

When I rebuilt and pushed to ECR, App Runner picked up the new image
and started running it. In about 5 minutes, the service was up and
running. Huzzah!

Sadly, the ECR does not show the architecture of the image, and App
Runner doesn't check it before trying to run it so it can report
something useful. ``#AWSwishList``


My Django Needed a More Recent PostgreSQL
=========================================

After resolving the image architecture mismatch, the logs showed it
running the migration and creating the superuser, but when I tried to
access it by the URL, I got this error in the browser::

  NotSupportedError at /
  PostgreSQL 12 or later is required (found 11.18).
  Request Method:	GET
  Request URL:	http://XXXX.eu-west-3.awsapprunner.com/
  Django Version:	4.2.7
  Exception Type:	NotSupportedError
  Exception Value:
  PostgreSQL 12 or later is required (found 11.18).
  Exception Location:	/VENV/lib/python3.12/site-packages/django/db/backends/base/base.py, line 214, in check_database_version_supported

I tried upgrading Aurora to the most recent PostgreSQL, 15.3. This
failed to deploy with CloudFormation with an error about Serverless v1
not being supported.

Way down in the bottom right corner of the `RDS Create Database
<https://eu-west-3.console.aws.amazon.com/rds/home?region=eu-west-3#launch-dbinstance:>`_,
page, after chosing ``Aurora (PostgreSQL Compatible)`` page, it lists
compatible versions::

  Severless v1
  11.18, 13.9

So I updated my CloudFormation ``db.yaml`` to use ``13.9`` and after
maybe 15 minutes database migration, it was running and the app came
up.

Authentication Requires CSRF for App Runner
===========================================

When the app came back, I connected with the URL which App Runner
provided, but when I tried to connect to the Admin page to login, it
gave this trust error::

  Origin checking failed - https://XXX.eu-west-3.awsapprunner.com does
  not match any trusted origins.

So edit the ``dev.py`` to add a wildcard for my Paris region's
domain::

  CSRF_TRUSTED_ORIGINS=[
    'https://\*.us-east-1.awsapprunner.com',
    'https://\*.eu-west-3.awsapprunner.com',
  ]

(The backslash in the RST above protect the asterisk, but won't show
in the rendered HTML, and are not used in the .py file.)

S3 Storage Presigned URLs Didn't Work
====================================

When using django-storages to store media and static assets on S3, the
default is to generate presigned URLs that give time-limited read
access to objects in S3. The URLs signatures were failing consistently
with SignatureDoesNotMatch. This is a very difficult problem to track
down.

Instead of figuring it out, I've configured the S3 to allow setting
objects ACLs in the CloudFormation aws/s3.yaml::

      PublicAccessBlockConfiguration: # needed for PublicRead
        BlockPublicAcls: false
      OwnershipControls:        # needed for PublicRead and setting object ACL
        Rules:
          - ObjectOwnership: ObjectWriter

Then configure our ``dev.py`` settings file to set ``public-read`` and
not generate presigned URLs::

    STORAGES = {
        "default": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": {
                "bucket_name": bucket_name,
                # The default presigned URL (running on Docker) has problems:
                # SignatureDoesNotMatch, so don't use them, set objects readable
                "default_acl": "public-read",
                "querystring_auth": False  # don't generate presigned URLs, they fail now
            },
        },
        "staticfiles": {
            "BACKEND": "storages.backends.s3.S3Storage",
            "OPTIONS": {
                "bucket_name": bucket_name,
                "default_acl": "public-read",
                "querystring_auth": False  # don't generate presigned URLs, they fail now
            },
    },

This got the site to render, after I ran ``collectstatic`` locally.
But image and document uploads failed.

Wagtail Upload fails on /add timeout
====================================

When running in App Runner, Wagtail image and document upload fail;
the icon shows up and preview says "100%" but the browser console
shows ``add/`` is ``pending`` for 2 minutes then times out::

    Request URL: https://ykcgyztfmf.eu-west-3.awsapprunner.com/admin/images/multiple/add/
    Request Method: POST
    Status Code: 502 Bad Gateway
    Remote Address: 35.180.239.62:443
    Referrer Policy: same-origin

In the app logs we see the timeout::

  urllib3.exceptions.ConnectTimeoutError:
  (<botocore.awsrequest.AWSHTTPSConnection object at 0x7fbd4f3c8c20>,
  'Connection to
  scale0-dev-s3-11vqj0ojwb6rf-s3mediabucket-1vf5f69qujs46.s3.eu-west-3.amazonaws.com
  timed out. (connect timeout=60)')
  ...
  botocore.exceptions.ConnectTimeoutError: Connect timeout on endpoint
  URL:
  "https://scale0-dev-s3-11vqj0ojwb6rf-s3mediabucket-1vf5f69qujs46.s3.eu-west-3.amazonaws.com/original_images/chris-candle.jpg"

Running locally, with my full IAM rights, worked fine.

It turned out that (in addition to sane IAM for S3) I had to create a
VPC Endpoint to S3 so that App Runner could reach it.

This works fine with Django Storages default non-public-read ACL and
its presigned URLs to the resources, so we can lock down the bucket.
