======
 TODO
======


* Load test to scale up apprunner: brew install hey: hey -z 5m

* S3 how to use or not-use S3 for local?

* S3 How to "manage.py collectstatic" from AWS App Runner? Or at least
  doc it in the Docker version.

* separate local from dev? how?
  os.environ.setdefault("DJANGO_SETTINGS_MODULE", "ncrp.settings.dev")
* 18:41:50 Just tried to connect to service, woke up 18:42:31: does
  Django have a wait-for-db setting in place?
* dj_database_url for AWS

* Get S3 name for Docker: aws cloudformation
  describe-stacks --stack-name scale0-dev --query "Stacks[0]"



In Progress
===========


SOON
====


LATER
=====

Django Storages: fix presigned URLs so we don't have to make objects public-read

Set CloudWatch logs to expire in 30 days

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



Is there any reason to use an AmazonLinux with SessionManager access? Is there such a thing for AppRunner? Any way to see logs?

Is there a way to use Tailscale to VPN into it?

Shoudl I build one with AMD tagged for ECR, and the other for macOS
ARM tagged simply?

Should I switch to finch??

