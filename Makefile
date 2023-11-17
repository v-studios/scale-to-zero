# Create an ECR Repo (if it doesn't exist); build, tag, push the image.
# Repo name must match that used by aws/apprunner.yml,
# our pattern is APP_NAME:OP_ENV (e.g., :dev, scale0:qa, scale0:prod)

APP_NAME         := scale0
OP_ENV           ?= dev
NAME_TAG         := ${APP_NAME}:${OP_ENV}
IMAGE_LOCAL	 := ${NAME_TAG}
AWS_REGION       := eu-west-3
AWS_ACCOUNT      := $(shell aws sts get-caller-identity --query Account --output text)
ECR_REG          := ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
ECR_REG_URL      := https://${ECR_REG}
ECR_REG_REPO_TAG := ${ECR_REG}/${NAME_TAG}

DOCKER_OPTS      := docker run -it --rm \
		    -p 8000:8000 \
		    -v `pwd`/db:/app/db \
		    -v `pwd`/media:/app/media \
		    -e DATABASE_URL="sqlite:////app/db/scale0.sqlite" \
		    --name ${APP_NAME}
DOCKER_RUN       := ${DOCKER_OPTS} ${IMAGE_LOCAL}
DOCKER_BASH      := ${DOCKER_RUN} bash
DOCKER_S3_BASH   := ${DOCKER_OPTS} \
		    -v ${HOME}/.aws/credentials:/root/.aws/credentials \
		    -e AWS_STORAGE_BUCKET_NAME \
		    -e AWS_PROFILE=chris@chris+hack \
		    ${IMAGE_LOCAL} bash

# TODO get the name from the stack, but it won't change after first deployment
AWS_STORAGE_BUCKET_NAME := scale0-dev-s3-11vqj0ojwb6rf-s3mediabucket-1vf5f69qujs46

# First, targets to get this running locally:
# CAUTION: I'm on a Apple M1 laptop, but AppRunner's using AMD64 so build for that;
# otherwise we'll see "exec format error" in App Runner's application logs.
# This will make execution on macOS slower, but that's OK, it'll work.
build: Dockerfile
	docker build --platform linux/amd64 --progress=plain -t ${APP_NAME}:${OP_ENV} .
	docker build --platform linux/amd64 --progress=plain -t ${ECR_REG_REPO_TAG} .

run:
	$(DOCKER_RUN)

bash:
	$(DOCKER_BASH)

s3_bash bash_s3:
	$(DOCKER_S3_BASH)
exec:
	@echo Connecting to running instance...
	docker exec -it ${APP_NAME} bash

# The targets to deploy containers to AWS ECR; also uses `build` above:

ecr_push: build ecr_login ecr_create
	docker push ${ECR_REG_REPO_TAG}

ecr_login:
	aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REG_URL}

ecr_create: ecr_login
	aws ecr describe-repositories --repository-names=${APP_NAME} || aws ecr create-repository --repository-name ${APP_NAME}

