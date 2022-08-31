IMAGE_NAME = uofa/s2i-shepherd-drupal

.PHONY: build
build:
	docker build -t $(IMAGE_NAME) .

tag:
	docker tag $(IMAGE_NAME) uofa/s2i-shepherd-drupal:openshift-4.x

push:
	docker push uofa/s2i-shepherd-drupal:openshift-4.x

.PHONY: test
test:
	docker build -t $(IMAGE_NAME)-candidate .
	IMAGE_NAME=$(IMAGE_NAME)-candidate test/run
