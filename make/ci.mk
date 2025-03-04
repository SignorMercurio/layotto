# Copyright 2021 Layotto Authors
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
 

APPS ?= faas integrate
APP_PLATFORMS = linux_amd64 linux_arm64 

.PHONY: app.image
app.image: image.verify  $(addprefix app.image., $(addprefix $(IMAGE_PLAT)., $(APPS)))

.PHONY: app.image.multiarch
app.image.multiarch: image.verify  $(foreach p,$(APP_PLATFORMS),$(addprefix app.image., $(addprefix $(p)., $(APPS))))

.PHONY: app.image.%
app.image.%:
	$(eval PLATFORM := $(word 1,$(subst ., ,$*)))
	$(eval APP := $(word 2,$(subst ., ,$*)))
	$(eval ARCH := $(word 2,$(subst _, ,$(PLATFORM))))
	$(eval IMAGE_PLAT := $(subst _,/,$(PLATFORM)))
	@echo "===========> Building docker image $(APP) $(VERSION) for $(IMAGE_PLAT)"
	@mkdir -p $(TMP_DIR)/$(APP)
	@cat $(ROOT_DIR)/docker/app/$(APP)/Dockerfile\
		>$(TMP_DIR)/$(APP)/Dockerfile
	$(eval BUILD_SUFFIX := $(_DOCKER_BUILD_EXTRA_ARGS) --pull -t $(REGISTRY_PREFIX)/$(APP)-$(ARCH):$(VERSION) $(TMP_DIR)/$(APP))
	$(DOCKER) build --platform $(IMAGE_PLAT) $(BUILD_SUFFIX)

.PHONY: checker.deadlink
checker.deadlink:
	@echo "===========> Checking Dead Links"
	sh ${SCRIPT_DIR}/check-dead-link.sh

QUICKSTART_VERSION ?= default

.PHONY: checker.quickstart
checker.quickstart:
	@echo "===========> Checking QuickStart Doc"
	sh ${SCRIPT_DIR}/test-quickstart.sh ${QUICKSTART_VERSION}

.PHONY: checker.coverage
checker.coverage:
	@echo "===========> Coverage Analysis"
	sh ${SCRIPT_DIR}/report.sh

.PHONY: integration.wasm
integration.wasm: app.image.linux_amd64.faas
	@echo "===========> Integration Test With WASM"
	$(eval ACTION := sh ./wasm_test.sh)
	$(eval ARCH := $(word 2,$(subst _, ,$(PLATFORM))))
	$(eval BUILD_IMAGE := $(REGISTRY_PREFIX)/faas-$(ARCH):$(VERSION))
	$(eval WORKDIR := -w /go/src/${PROJECT_NAME} )
	$(eval INTEGRATE_SUFFIX := -v $(ROOT_DIR):/go/src/${PROJECT_NAME} -v ${TEST_DIR}/wasm/wasm_test.sh:/go/src/${PROJECT_NAME}/wasm_test.sh $(WORKDIR))
	$(DOCKER) run --rm $(INTEGRATE_SUFFIX) $(BUILD_IMAGE) $(ACTION)

.PHONY: integration.runtime
integration.runtime: app.image.linux_amd64.integrate
	@echo "===========> Integration Test With Runtime"
	$(eval ACTION := sh ./integrate_test.sh)
	$(eval ARCH := $(word 2,$(subst _, ,$(PLATFORM))))
	$(eval BUILD_IMAGE := $(REGISTRY_PREFIX)/integrate-$(ARCH):$(VERSION))
	$(eval WORKDIR := -w /go/src/${PROJECT_NAME} )
	$(eval INTEGRATE_SUFFIX := -v $(ROOT_DIR):/go/src/${PROJECT_NAME} -v ${TEST_DIR}/runtime/integrate_test.sh:/go/src/${PROJECT_NAME}/integrate_test.sh $(WORKDIR))
	$(DOCKER) run --rm $(INTEGRATE_SUFFIX) ${BUILD_IMAGE} $(ACTION)
