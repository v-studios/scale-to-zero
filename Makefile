# Create an ECR Repo (if it doesn't exist); build, tag, push the image.
# Repo name must match that used by aws/apprunner.yml,
# our pattern is APP_NAME:OP_ENV (e.g., wagrun:dev, wagrun:qa, wagrun:prod)

APP_NAME         := wagrun
OP_ENV           ?= dev
NAME_TAG         := ${APP_NAME}:${OP_ENV}
AWS_REGION       := us-east-1
AWS_ACCOUNT      := $(shell aws sts get-caller-identity --query Account --output text)
ECR_REG          := ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
ECR_REG_URL      := https://${ECR_REG}
ECR_REG_REPO_TAG := ${ECR_REG}/${NAME_TAG}

ecr_push: build ecr_login ecr_create
	docker push ${ECR_REG_REPO_TAG}

build: Dockerfile
	docker build --progress=plain -t ${APP_NAME}:${OP_ENV} .
	docker build --progress=plain -t ${ECR_REG_REPO_TAG} .

ecr_login:
	aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REG_URL}

ecr_create: ecr_login
	aws ecr describe-repositories --repository-names=${APP_NAME} || aws ecr create-repository --repository-name ${APP_NAME}
