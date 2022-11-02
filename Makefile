IMAGE_NAME = uofa/s2i-shepherd-drupal

.PHONY: build
build:
	docker build -t $(IMAGE_NAME) .

tag:
	docker tag $(IMAGE_NAME) uofa/s2i-shepherd-drupal:openshift-4.x-22.04-php8.1

push:
	docker push uofa/s2i-shepherd-drupal:openshift-4.x-22.04-php-8.1

.PHONY: test
test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
