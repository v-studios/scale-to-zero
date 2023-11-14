# Create an ECR Repo (if it doesn't exist); build, tag, push the image.
# Repo name must match that used by aws/apprunner.yml,
# our pattern is APP_NAME:OP_ENV (e.g., :dev, scale0:qa, scale0:prod)

APP_NAME         := scale0
OP_ENV           ?= dev
NAME_TAG         := ${APP_NAME}:${OP_ENV}
AWS_REGION       := eu-west-3
AWS_ACCOUNT      := $(shell aws sts get-caller-identity --query Account --output text)
ECR_REG          := ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com
ECR_REG_URL      := https://${ECR_REG}
ECR_REG_REPO_TAG := ${ECR_REG}/${NAME_TAG}

DOCKER_RUN       := docker run -it --rm \
		    -p 8000:8000 \
		    -v `pwd`/db:/app/db \
		    -v `pwd`/media:/app/media \
		    -e DATABASE_URL="sqlite:////app/db/scale0.sqlite" \
		    --name scale0 \
		    scale0:dev 
DOCKER_BASH      := $(DOCKER_RUN) bash

# First, targets to get this running locally:

build: Dockerfile
	docker build --progress=plain -t ${APP_NAME}:${OP_ENV} .
	docker build --progress=plain -t ${ECR_REG_REPO_TAG} .

run:
	$(DOCKER_RUN)

bash:
	$(DOCKER_BASH)


# The targets to deploy containers to AWS ECR; also uses `build` above:

ecr_push: build ecr_login ecr_create
	docker push ${ECR_REG_REPO_TAG}

ecr_login:
	aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REG_URL}

ecr_create: ecr_login
	aws ecr describe-repositories --repository-names=${APP_NAME} || aws ecr create-repository --repository-name ${APP_NAME}

