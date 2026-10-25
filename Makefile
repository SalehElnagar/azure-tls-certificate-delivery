.PHONY: validate test

validate:
	$(MAKE) -C examples/tls-certificate-automation validate

test:
	$(MAKE) -C examples/tls-certificate-automation test
