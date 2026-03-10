.PHONY: all test plugin-lint shellcheck

all: test plugin-lint shellcheck

test:
	@docker compose run --rm test

plugin-lint:
	@docker compose run --rm plugin-lint

shellcheck:
	@docker compose run --rm shellcheck
