# `make install && make run` builds the app and serves it at http://localhost:3000
export PATH := $(HOME)/.elan/bin:$(PATH)

.PHONY: install run dev test check lean

install: lean
	npm ci

# Installs elan (the Lean installer) if missing, then builds the Lean code,
# which also checks all the Lean proofs.
lean:
	@command -v lake >/dev/null 2>&1 || \
	  { curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none; }
	cd engine && lake build

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
	cd engine && lake build
