.PHONY: clean code-analysis deps outdated-dependencies utest test

all: build ;

clean:
	rm -rf _build deps mix.lock

code-analysis: deps
	mix credo --strict

deps: mix.exs
	mix deps.get
	touch deps

outdated-dependencies: deps
	mix hex.outdated

utest: deps
	mix test --no-start --exclude end_to_end

test: deps
	mix test
