# `make install && make run` builds the app, starts it and opens http://localhost:3000.
# Works on Linux, macOS, WSL, and Windows in Git Bash with GNU make.
export PATH := $(HOME)/.elan/bin:$(PATH)

URL := http://localhost:3000

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
	cd engine && lake build

# Builds the web app and serves it, and opens the browser once the server answers.
run: lean
	npm run build
	@( n=0; until curl -s -o /dev/null $(URL) || [ $$n -ge 60 ]; do n=$$((n+1)); sleep 1; done; \
	   $(OPEN) $(URL) >/dev/null 2>&1; echo "The app is at $(URL)" ) &
	npm start

dev:
	npm run dev

test:
	npm test

check:
	npm run typecheck
	npm test
	cd engine && lake build
