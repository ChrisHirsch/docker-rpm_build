EL=el6
IMAGE=chrishirsch/rpm_build_$(EL)
CONTAINER=rpm_build_$(EL)

build: 
	docker build --rm --tag "$(IMAGE)" .

clean:
	@rm -f .run
	@docker rm -f $(CONTAINER) 2>/dev/null |:

logs:
		docker logs -f $(CONTAINER)

shell: build
		docker run --rm --tty --interactive --entrypoint /bin/bash $(VOLUMES) "$(IMAGE)" 

push: build tag
	docker push $(IMAGE)

tag:
	docker tag -f $(IMAGE) $(IMAGE)
