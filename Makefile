# See the documentation on how to run the tests.

export DAV_SERVER := skip
export REMOTESTORAGE_SERVER := skip
export RADICALE_BACKEND := filesystem
export REQUIREMENTS := release
export TESTSERVER_BASE := ./tests/storage/servers/
export CI := false
export COVERAGE := $(CI)
export DETERMINISTIC_TESTS := false
export ETESYNC_TESTS := false

CODECOV_PATH = /tmp/codecov.sh

PYTEST_ARGS =
TEST_EXTRA_PACKAGES =
ifeq ($(COVERAGE), true)
	TEST_EXTRA_PACKAGES += pytest-cov
	PYTEST_ARGS += --cov-config .coveragerc --cov vdirsyncer
endif

ifeq ($(ETESYNC_TESTS), true)
	TEST_EXTRA_PACKAGES += git+https://github.com/etesync/journal-manager
	TEST_EXTRA_PACKAGES += django djangorestframework wsgi_intercept
endif

ifeq ($(CI), true)
test:
	curl -s https://codecov.io/bash > $(CODECOV_PATH)
	py.test $(PYTEST_ARGS) tests/unit/
	bash $(CODECOV_PATH) -c -F unit
	py.test $(PYTEST_ARGS) tests/system/
	bash $(CODECOV_PATH) -c -F system
	py.test $(PYTEST_ARGS) tests/storage/
	bash $(CODECOV_PATH) -c -F storage
else
test:
	py.test $(PYTEST_ARGS)
endif

all:
	$(error Take a look at https://vdirsyncer.pimutils.org/en/stable/tutorial.html#installation)

install-servers:
	set -ex; \
	for server in $(DAV_SERVER) $(REMOTESTORAGE_SERVER); do \
		if [ ! "$$(ls $(TESTSERVER_BASE)$$server/)" ]; then \
			git submodule update --init -- "$(TESTSERVER_BASE)$$server"; \
		fi; \
		(cd $(TESTSERVER_BASE)$$server && sh install.sh); \
	done

install-test: install-servers
	(python --version | grep -vq 'Python 3.3') || pip install enum34
	pip install -r test-requirements.txt
	set -xe && if [ "$$REQUIREMENTS" = "devel" ]; then \
		pip install -U --force-reinstall \
			git+https://github.com/DRMacIver/hypothesis \
			git+https://github.com/pytest-dev/pytest; \
	fi
	[ -z "$(TEST_EXTRA_PACKAGES)" ] || pip install $(TEST_EXTRA_PACKAGES)

install-style: install-docs
	pip install flake8 flake8-import-order flake8-bugbear>=17.3.0
	
style:
	flake8
	! git grep -i syncroniz */*
	! git grep -i 'text/icalendar' */*
	sphinx-build -W -b html ./docs/ ./docs/_build/html/
	python3 scripts/make_travisconf.py | diff -b .travis.yml -

travis-conf:
	python3 scripts/make_travisconf.py > .travis.yml

install-docs:
	pip install -r docs-requirements.txt

docs:
	cd docs && make html

sh:  # open subshell with default test config
	$$SHELL;

linkcheck:
	sphinx-build -W -b linkcheck ./docs/ ./docs/_build/linkcheck/

release:
	python setup.py sdist bdist_wheel upload

install-dev:
	pip install -e .
	[ "$(REMOTESTORAGE_SERVER)" = "skip" ] || pip install -e .[remotestorage]
	[ "$(ETESYNC_TESTS)" = "false" ] || pip install -e .[etesync]
	set -xe && if [ "$(REQUIREMENTS)" = "devel" ]; then \
	    pip install -U --force-reinstall \
			git+https://github.com/mitsuhiko/click \
			git+https://github.com/kennethreitz/requests; \
	elif [ "$(REQUIREMENTS)" = "minimal" ]; then \
		pip install -U --force-reinstall $$(python setup.py --quiet minimal_requirements); \
	fi

ssh-submodule-urls:
	git submodule foreach "\
		echo -n 'Old: '; \
		git remote get-url origin; \
		git remote set-url origin \$$(git remote get-url origin | sed -e 's/https:\/\/github\.com\//git@github.com:/g'); \
		echo -n 'New URL: '; \
		git remote get-url origin"

.PHONY: docs
