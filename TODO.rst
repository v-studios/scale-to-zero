======
 TODO
======

2023-11-17 13:15 START

* Django Storages: fix presigned URLs so we don't have to make objects public-read;
  Try presigned URLs for S3 now that we have the correct S3 name; if
  it works, remvoe public-read config and S3 object access.

* From Docker, uploaded chris-cancdle.jpg, see it in S3 with NO public
  read. View Sorce in admin UI and see a PSURL, which works!
  https://scale0-dev-s3-11vqj0ojwb6rf-s3mediabucket-1vf5f69qujs46.s3.amazonaws.com/images/chris-candle.original.jpg?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIASGHGC6ZD2BHNJDPY%2F20231117%2Feu-west-3%2Fs3%2Faws4_request&X-Amz-Date=20231117T123945Z&X-Amz-Expires=3600&X-Amz-SignedHeaders=host&X-Amz-Signature=1702b56edaa8803235211529ff5e3b4f5daa18ff2dc4f64eb9c0c93d5e998193

* Deployed to AWS, stylesheet URL is PSURL::
  https://scale0-dev-s3-11vqj0ojwb6rf-s3mediabucket-1vf5f69qujs46.s3.amazonaws.com/css/welcome_page.css?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=ASIASGHGC6ZDULBC7NT2%2F20231117%2Feu-west-3%2Fs3%2Faws4_request&X-Amz-Date=20231117T124639Z&X-Amz-Expires=3600&X-Amz-SignedHeaders=host&X-Amz-Security-Token=IQoJb3JpZ2luX2VjEF0aCWV1LXdlc3QtMyJHMEUCIQDwwLtWb01Hm3Yj1zU0qehNiAkBHak2z6OLXymDRyjOIwIgekfmCZa3V9RqzqON59gBDvBinan7R2WF2h051dLTFvIq6gIIpv%2F%2F%2F%2F%2F%2F%2F%2F%2F%2FARAAGgwxNTA4MDYzOTQ0MzkiDK8ND7MJqzS3HQ3j2yq%2BAkqVKmozrUIW6NkIhOghno%2Bu6k%2Fi6Ztz1ot7hEfwkjsWJ5RKXbukMXaDvEr2nfvUXP1NM3PoKs175IhsJT5apb08UxmVCydBaoRK3WDKwWdE7F7P3kC0Al6wmlautfIRp4oeGgL9RjcSHpjjNhJigwI4ljAiSId8oe%2FDYumxuMGiDpIOHBBRG%2BrKKLC8mZNfIBDE0VDtg5IUrfyxElf02RpCL0%2FU7zrTzJpBTE%2FUGFzaHHS1HJJaLrvcRZg3L9WWDTNTLLjZOQWmvyKr8CS8sNaQo4spfe6EtmSEPuqbk%2BvFNBUC9frGk6h78f7JUMXFBHgyCiX6WlRnzpAxlkFpyF58mgSesF3OdcG4cZA8vSslvK0fu4%2Blfz%2BlWzQ933qG3lPgJPc1CUM%2BgbYx5KNkH06jFpLiWXmXpJeKg9LJ%2BjD3v92qBjqPAUJNSt3cA2ICIYyathqcMmNst21gJGbJBZON3IULAqZlF6BZ9jEkxepYgCTGDe7qwWQRxfikAQa65Lpl6e3WWrOJzm6q6ME15YN4o1XwsAyX%2BZ4VGYQCZcbCOeLDwXsdTLZ8oQx%2FtAiq6dnsfuzyAh43DF8Ot%2F2iEWC7k1V5iMj7OyNZ2CBd4sF%2FIjwP72Kz&X-Amz-Signature=a56bfa1494dec8fee2452ec8017e3540ec1a37255812c1b75c6a2c244af4c43a

  It seemed to work, but when trying to upload files, after showing
  the preview, we don't see the form to add details and submit. In the
  browser network console, we see it hanging for 2 minutes on `add/`::

    Request URL:
    https://ykcgyztfmf.eu-west-3.awsapprunner.com/admin/images/multiple/add/
    Request Method:
    POST
    Status Code:
    502 Bad Gateway
    Remote Address:
    35.180.239.62:443
    Referrer Policy:
    same-origin

  In the app logs we see the timeout::

    urllib3.exceptions.ConnectTimeoutError:
    (<botocore.awsrequest.AWSHTTPSConnection object at
    0x7f12443629f0>, 'Connection to
    scale0-dev-s3-11vqj0ojwb6rf-s3mediabucket-1vf5f69qujs46.s3.eu-west-3.amazonaws.com
    timed out. (connect timeout=60)')

  This partial URL doesn't indicate whether it's using Presigned Auth or not.

  Trying to force ``"querystring_auth": True,`` didn't help.

  Revert to public-read with psurl False. Did not help.

  QUESTIONS: Why does this work on local Docker? because it's got full
  AWS rights? but I gave AppRunner s3:* Allow and it didn't help. Why
  did I see it -- after a delay -- load up the form, or was that on
  Docker?


* Load test to scale up apprunner: brew install hey: hey -z 5m

* S3 how to use or not-use S3 for local?

* 18:41:50 Just tried to connect to service, woke up 18:42:31: does
  Django have a wait-for-db setting in place?

* dj_database_url for AWS

* Get S3 name for Docker: aws cloudformation
  describe-stacks --stack-name scale0-dev --query "Stacks[0]"

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







LATER
=====

Set CloudWatch logs to expire in 30 days

Should I switch to finch?? Will it help building multiarchitecture builds?

