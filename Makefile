export PATH := $(HOME)/.elan/bin:$(PATH)

.PHONY: install run

# Installs elan (the Lean installer) if missing, then builds everything,
# which also checks all the Lean proofs.
install:
	@command -v lake >/dev/null 2>&1 || \
	  { curl -sSfL https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none; }
	lake build

run:
	lake exe poker
