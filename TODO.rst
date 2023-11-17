======
 TODO
======

2023-11-17 13:15 START


CloudFormation Package
======================

* Use ``cloudformation package`` to bundle all our templates (locally?
  or S3?) and deploy? But we still have to have the nedted ones on S3,
  right?::

    aws cloudformation package --template-file
    scale0-LOCAL.yaml --output yaml --s3-bucket
    scale0-cloudformation --s3-prefix LOCAL --output-template-file
    PACKAGED.yml

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







* Load test to scale up apprunner: brew install hey: hey -z 5m

* S3 how to use or not-use S3 for local?

* 18:41:50 Just tried to connect to service, woke up 18:42:31: does
  Django have a wait-for-db setting in place?

* dj_database_url for AWS

* Get S3 name for Docker: aws cloudformation
  describe-stacks --stack-name scale0-dev --query "Stacks[0]"



LATER
=====

Set CloudWatch logs to expire in 30 days

Should I switch to finch?? Will it help building multiarchitecture builds?





AppRunner Upload Image/Document `add/` times out
================================================

I've used the default presigned URLs and it seems to work, so we don't
need to set S3 objects to public-read.

It must be coincidence but today I'm not able to upload an image or
document: we see the preview and it says "100%" but then it hangs, not
showing the form to commit the upload. The browser console Network tab
shows ``add/`` timing out after 2 minutes.


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


If it's trying to do a POST/PUT to that without presigning, then of
course it will fail. Why doesn't it seem to be getting a presigned URL
instead of a bare one?

This works fine in Docker, it takes a second after the upload starts
to show the edit/submit form. The only difference I can think of is
that Docker is running with my AWS creds and therefore permissions.

