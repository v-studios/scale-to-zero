======
 TODO
======

In Progress
===========

2023-11-14 16:07:04 UTC+0100	Service	
CREATE_FAILED
Resource handler returned message: "Your service failed to create. Review the application logs to find the source of error and retry." (RequestToken: a164f3c8-45fd-b8a1-54e8-b1b184f853ed, HandlerErrorCode: NotStabilized)


App Runner Event Logs::

  11-14-2023 04:25:59 PM [AppRunner] Successfully created pipeline for automatic deployments.
  11-14-2023 04:26:00 PM [AppRunner] Pulling image 150806394439.dkr.ecr.eu-west-3.amazonaws.com/scale0 from ECR repository.
  11-14-2023 04:27:08 PM [AppRunner] Successfully copied the image from ECR.
  11-14-2023 04:27:19 PM [AppRunner] Provisioning instances and deploying image for publicly accessible service.
  11-14-2023 04:27:29 PM [AppRunner] Performing health check on port '8000'.
  [waiting...]d
  11-14-2023 04:28:23 PM [AppRunner] Your application stopped or failed to start. See logs for more information.  Container exit code: 1
  11-14-2023 04:28:41 PM [AppRunner] Deployment with ID : 7f05c57529fb4b5cb1191af5be19fc14 failed.

See WHAT logs for more information??

If I go into CloudWatch > Log Groups > /aws/apprunner/scale0-dev/$UUID/application I see::

  exec /bin/sh: exec format error

Is it because I built the image on an M1 Mac??
I'm on M1 Mac?

CloudWatch > Log groups > /aws/apprunner/scale0-dev/470c52b8edbc4a0a86f49c65e319f202/service > events has the stuff in the consle::

  [AppRunner] Successfully copied the image from ECR.
  [AppRunner] Provisioning instances and deploying image for publicly accessible service.
  [AppRunner] Performing health check on port '8000'.
  [AppRunner] Your application stopped or failed to start. See logs for more information.  Container exit code: 1

And teh ... > deployment has the same as the console Deployment Logs::

  11-14-2023 04:25:35 PM [AppRunner] Starting to pull your application image.
  11-14-2023 04:28:41 PM [AppRunner] Failed to deploy your application image.

Use ``docker image inspect scale0:dev`` and check the architecture::

        "Architecture": "arm64",

That's Apple silicon. We need AMD/Intel/X86; build --platform linux/amd64

Blogs hint we can build in parallel on macOS but i don't have ``lniux/amd``, only ``linux/arm64``::

  docker buildx ls
  NAME/NODE       DRIVER/ENDPOINT STATUS  BUILDKIT             PLATFORMS
  default                         error
  desktop-linux * docker
    desktop-linux desktop-linux   running v0.11.6+616c3f613b54 linux/arm64, linux/riscv64, linux/ppc64le, linux/s390x, linux/386, linux/mips64, linux/arm/v7, linux/arm/v6

  Cannot load builder default: Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?

I dn't know why it's complaining about inability to connect to a socket.

I can change my Makefile to build an AMD64 image::

  	docker build --platform linux/amd64 --progress=plain -t ${APP_NAME}:${OP_ENV} .
	docker build --platform linux/amd64 --progress=plain -t ${ECR_REG_REPO_TAG} .

Shoudl I build one with AMD tagged for ECR, and the other for macOS ARM tagged simply?

Should I switch to finch??

Should I use Fargate (app runner?) New ECS Experience for ARM?

May still not work::

  This wasn't enough. I needed to add the platform also to my FROM
  imports like FROM amd64/python:3.9-slim and only then I could
  successfully build a dockerfile for AMD on Apple M1 Pro with the
  command given above

eg::

  FROM --platform=linux/amd64 BASE_IMAGE:VERSION

ECR doesn't seem to show the CPU architecture.

Success?
--------

Modified makefile to build amd64 and hunt for application logs::

    Applying wagtailusers.0012_userprofile_theme... OK
    ###### DEV.PY goes searching for database
    ## database_url=''
    ## database_host='scale0dev.cluster-caoirfmotyxq.eu-west-3.rds.amazonaws.com' database_port='5432' database_name='scale0dev' database_user='dbuser' database_password='ChangeMe'
    Superuser created successfully.
    ###### DEV.PY goes searching for database
    ## database_url=''
    ## database_host='scale0dev.cluster-caoirfmotyxq.eu-west-3.rds.amazonaws.com' database_port='5432' database_name='scale0dev' database_user='dbuser' database_password='ChangeMe'
    ###### DEV.PY goes searching for database
    ## database_url=''
    ## database_host='scale0dev.cluster-caoirfmotyxq.eu-west-3.rds.amazonaws.com' database_port='5432' database_name='scale0dev' database_user='dbuser' database_password='ChangeMe'
    Watching for file changes with StatReloader
    Performing system checks...
    System check identified no issues (0 silenced).
    November 14, 2023 - 16:15:06
    Django version 4.2.7, using settings 'scale0.settings.dev'
    Starting development server at http://0.0.0.0:8000/
    Quit the server with CONTROL-C.

And the cloudformation stack completed!

The data migration and user creation worked but when I go to the URL
for the web, https://ykcgyztfmf.eu-west-3.awsapprunner.com/, I get::

  NotSupportedError at /
  PostgreSQL 12 or later is required (found 11.18).
  Request Method:	GET
  Request URL:	http://ykcgyztfmf.eu-west-3.awsapprunner.com/
  Django Version:	4.2.7
  Exception Type:	NotSupportedError
  Exception Value:
  PostgreSQL 12 or later is required (found 11.18).
  Exception Location:	/VENV/lib/python3.12/site-packages/django/db/backends/base/base.py, line 214, in check_database_version_supported
  Raised during:	wagtail.views.serve
  Python Executable:	/VENV/bin/python
  Python Version:	3.12.0
  Python Path:	
  ['/app',
   '/usr/local/lib/python312.zip',
   '/usr/local/lib/python3.12',
   '/usr/local/lib/python3.12/lib-dynload',
   '/VENV/lib/python3.12/site-packages']

On the DB Engine Fersions tab, it shows Serverless v1 only offers up to 13.9:
https://eu-west-3.console.aws.amazon.com/rds/home?region=eu-west-3#launch-dbinstance:;isHermesCreate=true

Updating with 13.9 loooking good so far, config page shows::

  Autoscaling timeout
  5 minutes
  Pause compute capacity after consecutive minutes of inactivity
  5 minutes

Finally came back, but when I connect to the URL I get a trust problem::

      Origin checking failed - https://ykcgyztfmf.eu-west-3.awsapprunner.com does not match any trusted origins.

So edit the dev.py to add it::

  CSRF_TRUSTED_ORIGINS=[
    'https://*.us-east-1.awsapprunner.com',
    'https://*.eu-west-3.awsapprunner.com',
  ]

SOON
====

Provide S3 for media (images/documents) presistence.


LATER
=====

Determine if AppRunner has useful sqlite (why?)

Is there any reason to use an AmazonLinux with SessionManager access? Is there such a thing for AppRunner? Any way to see logs?

Where are logs?

Use ``cloudformation package`` to bundle all our templates (locally?
or S3?) and deploy? But we still have to have the nedted ones on S3,
right?::

  aws cloudformation package --template-file scale0-LOCAL.yaml --output yaml --s3-bucket scale0-cloudformation --s3-prefix LOCAL --output-template-file PACKAGED.yml

It creates and uploads the three nested stack files to random names in
S3, then outputs a CF template with those substitutions. So basically
automating what I'm doing with my makefile and cp to s3. Excerpt::

  Resources:
    Vpc:
      Type: AWS::CloudFormation::Stack
      Properties:
        TemplateURL: https://s3.eu-west-3.amazonaws.com/scale0-cloudformation/LOCAL/b597c923bb38074a5a35fe80c7bf7be9.template
    Db:
      Type: AWS::CloudFormation::Stack
      Properties:
        TemplateURL: https://s3.eu-west-3.amazonaws.com/scale0-cloudformation/LOCAL/25ccd79658467ed77b54969d638e8e34.template
    AppRunner:
      Type: AWS::CloudFormation::Stack
      Properties:
        TemplateURL: https://s3.eu-west-3.amazonaws.com/scale0-cloudformation/LOCAL/9e5189040f7128ecd5b658fea7bc8c96.template

Then I can ``aws cloudformation deploy ...`` the generated file.

