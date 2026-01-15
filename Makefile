# my-claude Makefile
#
# Orchestrates Claude Code configuration deployment
#

.PHONY: all help install clean

all: install
	@echo ""
	@echo "✅ my-claude setup complete!"

help:
	@echo "my-claude - Claude Code Configuration"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  all      - Run full installation (default)"
	@echo "  install  - Deploy configuration to ~/.claude/"
	@echo "  clean    - Remove deployed configuration"
	@echo "  help     - Show this help message"

install:
	@echo "🤖 Installing my-claude configuration..."
	@./install.sh

clean:
	@echo "🧹 This will remove ~/.claude/ configuration."
	@echo "A backup will be created at ~/.claude-backup/"
	@echo "Are you sure? [y/N] " && read ans && [ $${ans:-N} = y ]
	@mkdir -p ~/.claude-backup
	@cp -r ~/.claude/ ~/.claude-backup/$$(date +%Y%m%d_%H%M%S) 2>/dev/null || true
	@rm -rf ~/.claude/
	@echo "✅ Configuration removed (backup in ~/.claude-backup/)"
