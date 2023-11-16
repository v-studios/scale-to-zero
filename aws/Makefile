# Use --disable-rollback so we keep most infra even though apprunner
# will fail first time due to no image in newly created ECR.
# Derp: that flag is only in aws-cli v1 which is deprecated!

APP_NAME  := scale0
OP_ENV    ?= dev
CF_BUCKET := ${APP_NAME}-cloudformation

help:
	@echo Check the Makefile for targets.

create_bucket:
	aws s3 mb s3://${CF_BUCKET}

deploy_dev deploy: copy_to_s3
	aws cloudformation deploy \
	--template-file scale0-dev.yaml \
	--stack-name scale0-dev \
	--disable-rollback \
	--capabilities CAPABILITY_NAMED_IAM \
	--parameter-overrides CfBucket=${CF_BUCKET}

copy_to_s3:
	aws s3 cp vpc.yaml       s3://${CF_BUCKET}
	aws s3 cp s3.yaml	 s3://${CF_BUCKET}
	aws s3 cp db.yaml        s3://${CF_BUCKET}
	aws s3 cp apprunner.yaml s3://${CF_BUCKET}
