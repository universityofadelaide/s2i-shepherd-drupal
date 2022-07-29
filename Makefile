IMAGE_NAME = uofa/s2i-shepherd-drupal:parking

.PHONY: build
build:
	docker build -t $(IMAGE_NAME) .

tag:
	docker tag $(IMAGE_NAME) uofa/s2i-shepherd-drupal:parking

push:
	docker push uofa/s2i-shepherd-drupal:parking

.PHONY: test
test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
