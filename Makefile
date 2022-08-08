# Use app_name for ECR repo too
APP_NAME := wagrun
APP_TAG  := latest 
OP_ENV   ?= dev
AWS_REGION := us-east-1
AWS_ACCOUNT := $(shell aws sts get-caller-identity --query Account --output text)
ECR_REG := ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
ECR_REG_URL = https://${ECR_REG}
ECR_REG_REPO_TAG := ${ECR_REG}/${APP_NAME}:${APP_TAG}

ecr_push: build ecr_login ecr_create
	docker push ${ECR_REG_REPO_TAG}

build: Dockerfile
	docker build -t ${APP_NAME} --progress=plain .
	docker build -t ${ECR_REG_REPO_TAG} .

ecr_login:
	aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REG_URL}

ecr_create: ecr_login
	aws ecr describe-repositories --repository-names=${APP_NAME} || aws ecr create-repository --repository-name ${APP_NAME}
