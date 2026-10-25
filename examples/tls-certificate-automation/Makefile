TERRAFORM ?= terraform
PYTHON ?= python3
TF_DATA_ROOT ?= $(shell mktemp -d)

.PHONY: test validate

test:
	$(PYTHON) scripts/local_tests.py

validate: test
	$(TERRAFORM) fmt -check -recursive bootstrap identity foundation edge
	@set -e; for root in bootstrap identity foundation edge; do \
	  TF_DATA_DIR="$(TF_DATA_ROOT)/$$root" $(TERRAFORM) -chdir="$$root" init -backend=false -input=false -lockfile=readonly; \
	  TF_DATA_DIR="$(TF_DATA_ROOT)/$$root" $(TERRAFORM) -chdir="$$root" validate; \
	  TF_DATA_DIR="$(TF_DATA_ROOT)/$$root" $(TERRAFORM) -chdir="$$root" test; \
	done
	actionlint pipelines/source-ci.yml
