# Use --disable-rollback so we keep most infra even though apprunner
# will fail first time due to no image in newly created ECR.
# Derp: that flag is only in aws-cli v1 which is deprecated!

deploy_dev deploy: copy_to_s3
	aws cloudformation deploy --template-file wagrun-dev.yaml  --stack-name wagrun-dev --capabilities CAPABILITY_NAMED_IAM

copy_to_s3:
	aws s3 cp vpc.yaml       s3://alps-cloudformation-izdev/apprunner/
	aws s3 cp db.yaml        s3://alps-cloudformation-izdev/apprunner/
	aws s3 cp apprunner.yaml s3://alps-cloudformation-izdev/apprunner/
