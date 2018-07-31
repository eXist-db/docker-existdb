include .env

build:
	docker build \
 --tag="$(DOCKER_IMAGE)" \
 .

up:
	docker-compose up -d


down:
	docker-compose down


setUpstream:
	@git branch --set-upstream-to=origin/develop enhance-10-build-stages
	git remote show origin
