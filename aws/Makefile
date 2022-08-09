deploy_dev deploy: copy_to_s3
	aws cloudformation deploy --template-file dev.yaml  --stack-name wagrun2-dev --capabilities CAPABILITY_NAMED_IAM

copy_to_s3:
	aws s3 cp vpc.yaml s3://alps-cloudformation-izdev/apprunner/
	aws s3 cp ecr.yaml s3://alps-cloudformation-izdev/apprunner/
	aws s3 cp db.yaml s3://alps-cloudformation-izdev/apprunner/
	aws s3 cp apprunner.yaml s3://alps-cloudformation-izdev/apprunner/
