# `make install && make run` builds the app and serves it at http://localhost:3000

.PHONY: install run dev test check

install:
	npm ci

run:
	npm run build
	npm start

dev:
	npm run dev

test:
	npm test

check:
	npm run typecheck
	npm test
