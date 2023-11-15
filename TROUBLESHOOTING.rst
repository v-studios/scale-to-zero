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

But the logs from the application itself are not available in the
console; they're in CloudWatch::

  /aws/apprunner/scale0-dev/$UUID/application/...

and under there, are logs for each instance, like:

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
running.

Sadly, the ECR does not show the architecture of the image, and App
Runner doesn't check it before trying to run it so it can report
something useful. ``#AWSwishList``


My Django Needed a More Recent PostgreSQL
=========================================

After resolving the image architecture mismatch, the logs showed it running the migration and creating the superuser, but when I tried to access it by the URL, I got this error in the browser::

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

So edit the ``dev.py`` to add a wildcard for my region's domain::

  CSRF_TRUSTED_ORIGINS=[
    'https://\*.us-east-1.awsapprunner.com',
    'https://\*.eu-west-3.awsapprunner.com',
  ]

(The backslash in the RST protect the asterisk, but won't show in the
rendered HTML, and are not used in the .py file.)
