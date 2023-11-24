
APP_NAME   := scale0
OP_ENV     ?= dev
CF_BUCKET  := ${APP_NAME}-cloudformation
STACK_NAME := ${APP_NAME}-${OP_ENV}

help:
	@echo "`make deploy` will package the nested stacks and deploy to AWS"
	@echo "`make create_s3` is a one-time to create the CloudFormation bucket"

# Use --disable-rollback so we keep most infra even if apprunner fails
# the first time due to no image in newly created ECR. Derp:
cf_deploy deploy: ${STACK_NAME}-packaged.yaml
	aws cloudformation deploy \
        --template-file ${STACK_NAME}-packaged.yaml \
        --stack-name ${STACK_NAME} \
	--disable-rollback \
	--capabilities CAPABILITY_NAMED_IAM

cf_package ${STACK_NAME}-packaged.yaml: ${STACK_NAME}.yaml apprunner.yaml db.yaml s3.yaml vpc.yaml
	aws cloudformation package \
	--template-file ${STACK_NAME}.yaml \
	--s3-bucket ${CF_BUCKET} \
	--output yaml \
	--output-template-file ${STACK_NAME}-packaged.yaml

create_s3:
	aws s3 mb s3://${CF_BUCKET}
