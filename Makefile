# `make install && make run` builds the app, starts it and opens http://localhost:3000.
# Works on Linux, macOS, WSL, and Windows in Git Bash with GNU make.
# Use another port with `make run PORT=3001`.
export PATH := $(HOME)/.elan/bin:$(PATH)

PORT ?= 3000
URL := http://localhost:$(PORT)

# How to open the browser on this system.
ifeq ($(OS),Windows_NT)
  OPEN := explorer.exe
else ifeq ($(shell uname -s),Darwin)
  OPEN := open
else ifneq ($(shell grep -qi microsoft /proc/version 2>/dev/null && echo wsl),)
  OPEN := explorer.exe
else
  OPEN := xdg-open
endif

.PHONY: install run dev test check lean

install: lean
	npm ci

# Installs elan (the Lean installer) if missing, then builds the Lean code and the `poker`
# program, which also checks all the Lean proofs. elan fetches the Lean version that
# engine/lean-toolchain names.
lean:
	@command -v lake >/dev/null 2>&1 || \
	  { curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none; }
	cd engine && lake build && lake build kuhn-serve

# Builds the web app and serves it, and opens the browser once the server answers. Stops
# first if another server already answers on the port, so the browser never opens the wrong app.
run: lean
	npm run build
	@if curl -s -o /dev/null $(URL); then \
	  echo "Port $(PORT) is already in use. Stop that server, or run: make run PORT=3001"; exit 1; fi
	@( for i in $$(seq 60); do \
	     if curl -s -o /dev/null $(URL); then $(OPEN) $(URL) >/dev/null 2>&1; echo "The app is at $(URL)"; exit 0; fi; \
	     sleep 1; done ) &
	npm start -- --port $(PORT)

dev:
	npm run dev

test: lean
	npm test

check: lean
	npm run typecheck
	npm test
