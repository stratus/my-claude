# my-claude Makefile
#
# Orchestrates Claude Code configuration deployment
#
# CLAUDE_TARGETS: space-separated list of directories to install into.
# Defaults to ~/.claude. Override to deploy to multiple instances:
#   make install CLAUDE_TARGETS="~/.claude ~/.claude-corp"
#

CLAUDE_TARGETS ?= ~/.claude

.PHONY: all help install clean

all: install
	@echo ""
	@echo "✅ my-claude setup complete!"

help:
	@echo "my-claude - Claude Code Configuration"
	@echo ""
	@echo "Usage: make [target] [CLAUDE_TARGETS='~/.claude ~/.claude-corp']"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Run full installation (default)"
	@echo "  install  - Deploy configuration to target directories"
	@echo "  clean    - Remove deployed configuration"
	@echo "  help     - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  CLAUDE_TARGETS  - Space-separated install dirs (default: ~/.claude)"
	@echo "  FORCE_UPDATE    - Set to 1 to skip prompts on diverged files"

install:
	@for target in $(CLAUDE_TARGETS); do \
		echo ""; \
		echo "🤖 Installing my-claude configuration to $$target..."; \
		CLAUDE_DIR="$$target" ./install.sh; \
	done

clean:
	@for target in $(CLAUDE_TARGETS); do \
		echo "🧹 This will remove $$target configuration."; \
	done
	@echo "A backup will be created first."
	@echo "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@for target in $(CLAUDE_TARGETS); do \
		backup_name="$$(basename $$target)"; \
		mkdir -p ~/.claude-backup; \
		cp -r "$$target" ~/.claude-backup/$${backup_name}_$$(date +%Y%m%d_%H%M%S) 2>/dev/null || true; \
		rm -rf "$$target"; \
		echo "✅ $$target removed"; \
	done
	@echo "Backups saved to ~/.claude-backup/"
