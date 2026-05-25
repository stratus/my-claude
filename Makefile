# my-claude Makefile
#
# Orchestrates Claude Code configuration deployment
#
# CLAUDE_TARGETS: space-separated list of directories to install into.
# Defaults to ~/.claude. Override to deploy to multiple instances:
#   make install CLAUDE_TARGETS="~/.claude ~/.claude-corp"
#

CLAUDE_TARGETS ?= ~/.claude

.PHONY: all help install clean set-identity unset-identity unset-git-identity reset-all-identity set-statusline unset-statusline

all: install
	@echo ""
	@echo "✅ my-claude setup complete!"

help:
	@echo "my-claude - Claude Code Configuration"
	@echo ""
	@echo "Usage: make [target] [CLAUDE_TARGETS='~/.claude ~/.claude-corp']"
	@echo ""
	@echo "Targets:"
	@echo "  all                 - Run full installation (default)"
	@echo "  install             - Deploy configuration to target directories"
	@echo "  set-identity        - Configure git name/email + Auto Mode identity per target"
	@echo "  unset-identity      - Remove identity overlay and revert settings.json placeholders"
	@echo "  unset-git-identity  - Remove the [includeIf] stanzas this tooling wrote to ~/.gitconfig"
	@echo "  reset-all-identity  - Full revert: unset-git-identity + unset-identity"
	@echo "  set-statusline      - Choose statusline backend (rz1989s | tmck | none); persists per target"
	@echo "  unset-statusline    - Remove statusline-choice marker and restore default (rz1989s)"
	@echo "  clean               - Remove deployed configuration"
	@echo "  help                - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  CLAUDE_TARGETS       - Space-separated install dirs (default: ~/.claude)"
	@echo "  FORCE_UPDATE         - Set to 1 to skip prompts on diverged files"
	@echo "  STATUSLINE_CHOICE    - Override the statusline backend for this run only"
	@echo "                         (rz1989s | tmck | none). Does NOT persist to marker"
	@echo "                         unless set via 'make set-statusline'."

install:
	@sl="$${STATUSLINE_CHOICE:-}"; \
	if [ -z "$$sl" ] && [ ! -f "$$HOME/.claude/statusline-choice" ]; then \
		sl="$$(./scripts/prompt-statusline.sh)"; \
	fi; \
	for target in $(CLAUDE_TARGETS); do \
		echo ""; \
		echo "🤖 Installing my-claude configuration to $$target..."; \
		if [ -n "$$sl" ]; then \
			STATUSLINE_CHOICE="$$sl" CLAUDE_DIR="$$target" ./install.sh; \
		else \
			CLAUDE_DIR="$$target" ./install.sh; \
		fi; \
	done

set-identity:
	@for target in $(CLAUDE_TARGETS); do \
		CLAUDE_DIR="$$target" ./scripts/set-identity.sh; \
	done

unset-identity:
	@for target in $(CLAUDE_TARGETS); do \
		rm -f "$$target/identity.json"; \
		echo "✅ Removed identity overlay for $$target"; \
	done
	@FORCE_UPDATE=1 $(MAKE) install

unset-git-identity:
	@for target in $(CLAUDE_TARGETS); do \
		CLAUDE_DIR="$$target" ./scripts/unset-git-identity.sh; \
	done

reset-all-identity: unset-git-identity unset-identity
	@echo ""
	@echo "✅ Identity fully reset for $(CLAUDE_TARGETS)"

# set-statusline accepts an optional CHOICE argument:
#   make set-statusline                  (interactive prompt)
#   make set-statusline CHOICE=tmck      (non-interactive)
# `|| exit 1` aborts the per-target loop on invalid input so the user sees a
# single error rather than one per target.
set-statusline:
	@for target in $(CLAUDE_TARGETS); do \
		CLAUDE_DIR="$$target" ./scripts/set-statusline.sh $(CHOICE) || exit 1; \
	done

unset-statusline:
	@for target in $(CLAUDE_TARGETS); do \
		CLAUDE_DIR="$$target" ./scripts/unset-statusline.sh || exit 1; \
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
