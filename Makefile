.PHONY: help run run-bg custom-brief custom-brief-bg tail log logs status install uninstall clean-logs check validate prompt

SHELL := /bin/bash
DATE  := $(shell date +%Y-%m-%d)

# Detect platform
UNAME := $(shell uname -s 2>/dev/null || echo Windows)
ifeq ($(findstring MINGW,$(UNAME)),MINGW)
  PLATFORM := windows
else ifeq ($(findstring MSYS,$(UNAME)),MSYS)
  PLATFORM := windows
else ifeq ($(findstring CYGWIN,$(UNAME)),CYGWIN)
  PLATFORM := windows
else ifeq ($(UNAME),Darwin)
  PLATFORM := macos
else ifeq ($(UNAME),Windows)
  PLATFORM := windows
else
  PLATFORM := linux
endif

# Paths
SCRIPT_DIR := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)
LOG_DIR    := $(SCRIPT_DIR)/logs
LOG_FILE   := $(LOG_DIR)/$(DATE).log

ifeq ($(PLATFORM),windows)
  CLAUDE := $(HOME)/.local/bin/claude.exe
else
  CLAUDE := $(HOME)/.local/bin/claude
endif

## —— Help ————————————————————————————————————————————
help: ## Show this help
	@echo ""
	@echo "  AI News Briefing — Makefile targets"
	@echo "  ════════════════════════════════════"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Platform detected: $(PLATFORM)"
	@echo ""

## —— Run ——————————————————————————————————————————————
run: check ## Run the briefing now (foreground). Options: D=2026-03-15 CLI=codex
ifeq ($(PLATFORM),windows)
	@powershell -ExecutionPolicy Bypass -File "$(SCRIPT_DIR)/briefing.ps1" $(if $(D),-BriefingDate $(D)) $(if $(CLI),-Cli $(CLI))
else
	@bash "$(SCRIPT_DIR)/briefing.sh" $(if $(D),--date $(D)) $(if $(CLI),--cli $(CLI))
endif

run-bg: check ## Run the briefing in background. Options: D=2026-03-15 CLI=codex
ifeq ($(PLATFORM),windows)
	@echo "[$(or $(D),$(DATE))] Starting briefing in background..."
	@powershell -ExecutionPolicy Bypass -File "$(SCRIPT_DIR)/briefing.ps1" $(if $(D),-BriefingDate $(D)) $(if $(CLI),-Cli $(CLI)) &
	@echo "Running. Tail log with: make tail"
else
	@echo "[$(or $(D),$(DATE))] Starting briefing in background..."
	@nohup bash "$(SCRIPT_DIR)/briefing.sh" $(if $(D),--date $(D)) $(if $(CLI),--cli $(CLI)) >/dev/null 2>&1 &
	@echo "Running (PID $$!). Tail log with: make tail"
endif

custom-brief: check ## Deep-research a topic. Usage: make custom-brief T="topic" CLI=codex NOTION=1 TEAMS=1 SLACK=1
ifeq ($(PLATFORM),windows)
	@powershell -ExecutionPolicy Bypass -File "$(SCRIPT_DIR)/custom-brief.ps1" \
		$(if $(T),-Topic "$(T)") \
		$(if $(CLI),-Cli $(CLI)) \
		$(if $(NOTION),-Notion) \
		$(if $(TEAMS),-Teams) \
		$(if $(SLACK),-Slack)
else
	@bash "$(SCRIPT_DIR)/custom-brief.sh" \
		$(if $(T),--topic "$(T)") \
		$(if $(CLI),--cli $(CLI)) \
		$(if $(NOTION),--notion) \
		$(if $(TEAMS),--teams) \
		$(if $(SLACK),--slack)
endif

custom-brief-bg: check ## Deep-research in background. Usage: make custom-brief-bg T="topic" CLI=gemini NOTION=1
ifeq ($(PLATFORM),windows)
	@echo "Starting custom brief in background..."
	@powershell -ExecutionPolicy Bypass -File "$(SCRIPT_DIR)/custom-brief.ps1" \
		$(if $(T),-Topic "$(T)") \
		$(if $(CLI),-Cli $(CLI)) \
		$(if $(NOTION),-Notion) \
		$(if $(TEAMS),-Teams) \
		$(if $(SLACK),-Slack) &
	@echo "Running. Check logs/custom-*.log"
else
	@echo "Starting custom brief in background..."
	@nohup bash "$(SCRIPT_DIR)/custom-brief.sh" \
		$(if $(T),--topic "$(T)") \
		$(if $(CLI),--cli $(CLI)) \
		$(if $(NOTION),--notion) \
		$(if $(TEAMS),--teams) \
		$(if $(SLACK),--slack) >/dev/null 2>&1 &
	@echo "Running (PID $$!). Check logs/custom-*.log"
endif

run-scheduled: ## Trigger the scheduled task (via OS scheduler)
ifeq ($(PLATFORM),macos)
	@launchctl kickstart "gui/$$(id -u)/com.ainews.briefing"
	@echo "Kicked. Tail log with: make tail"
else ifeq ($(PLATFORM),windows)
	@schtasks //run //tn AiNewsBriefing
	@echo "Triggered. Tail log with: make tail"
else
	@echo "No scheduler configured for Linux. Use: make run"
endif

## —— Logs —————————————————————————————————————————————
tail: ## Tail today's log (live)
	@mkdir -p "$(LOG_DIR)"
	@touch "$(LOG_FILE)"
	@tail -f "$(LOG_FILE)"

log: ## Print today's log
	@if [ -f "$(LOG_FILE)" ]; then \
		cat "$(LOG_FILE)"; \
	else \
		echo "No log for today ($(DATE)). Has the briefing run?"; \
	fi

logs: ## List all log files with sizes
	@if [ -d "$(LOG_DIR)" ]; then \
		ls -lh "$(LOG_DIR)"/*.log 2>/dev/null || echo "No logs found."; \
	else \
		echo "No logs directory yet."; \
	fi

log-date: ## Print log for a specific date (usage: make log-date D=2026-03-09)
	@if [ -z "$(D)" ]; then \
		echo "Usage: make log-date D=YYYY-MM-DD"; \
	elif [ -f "$(LOG_DIR)/$(D).log" ]; then \
		cat "$(LOG_DIR)/$(D).log"; \
	else \
		echo "No log found for $(D)."; \
	fi

clean-logs: ## Delete logs older than 30 days
	@if [ -d "$(LOG_DIR)" ]; then \
		find "$(LOG_DIR)" -name "*.log" -mtime +30 -delete 2>/dev/null; \
		echo "Cleaned logs older than 30 days."; \
	else \
		echo "No logs directory."; \
	fi

purge-logs: ## Delete ALL logs
	@if [ -d "$(LOG_DIR)" ]; then \
		rm -f "$(LOG_DIR)"/*.log; \
		echo "All logs deleted."; \
	else \
		echo "No logs directory."; \
	fi

## —— Scheduler ————————————————————————————————————————
install: check ## Install the platform scheduler (daily 8:00 AM)
ifeq ($(PLATFORM),macos)
	@chmod +x "$(SCRIPT_DIR)/briefing.sh"
	@cp "$(SCRIPT_DIR)/com.ainews.briefing.plist" ~/Library/LaunchAgents/
	@launchctl load ~/Library/LaunchAgents/com.ainews.briefing.plist
	@echo "macOS launchd agent installed (daily 8:00 AM)."
else ifeq ($(PLATFORM),windows)
	@powershell -ExecutionPolicy Bypass -File "$(SCRIPT_DIR)/install-task.ps1"
	@echo "Windows Task Scheduler task installed."
else
	@echo "Linux: no installer yet. Add a cron entry manually:"
	@echo "  0 8 * * * bash $(SCRIPT_DIR)/briefing.sh"
endif

uninstall: ## Remove the platform scheduler
ifeq ($(PLATFORM),macos)
	@launchctl unload ~/Library/LaunchAgents/com.ainews.briefing.plist 2>/dev/null || true
	@rm -f ~/Library/LaunchAgents/com.ainews.briefing.plist
	@echo "macOS launchd agent removed."
else ifeq ($(PLATFORM),windows)
	@schtasks //delete //tn AiNewsBriefing //f 2>/dev/null || true
	@echo "Windows scheduled task removed."
else
	@echo "Remove the cron entry manually: crontab -e"
endif

status: ## Show scheduler status
ifeq ($(PLATFORM),macos)
	@launchctl list 2>/dev/null | grep ainews || echo "Not installed."
else ifeq ($(PLATFORM),windows)
	@schtasks //query //tn AiNewsBriefing 2>/dev/null || echo "Not installed."
else
	@crontab -l 2>/dev/null | grep briefing || echo "No cron entry found."
endif

## —— Validate —————————————————————————————————————————
check: ## Verify at least one supported AI CLI is installed
	@found=0; \
	for cli in claude codex gemini copilot gh; do \
		if command -v $$cli >/dev/null 2>&1; then \
			printf "  %-12s \033[32mOK\033[0m (%s)\n" "$$cli" "$$(command -v $$cli)"; \
			found=1; \
		fi; \
	done; \
	if [ -f "$(CLAUDE)" ]; then \
		printf "  %-12s \033[32mOK\033[0m (%s)\n" "claude" "$(CLAUDE)"; \
		found=1; \
	fi; \
	if [ $$found -eq 0 ]; then \
		echo "ERROR: No supported AI CLI found (claude, codex, gemini, copilot)."; \
		echo "Install at least one. See README.md for details."; \
		exit 1; \
	fi

validate: check ## Validate all project files exist and are well-formed
	@echo "Checking project files..."
	@errors=0; \
	for f in prompt.md briefing.sh briefing.ps1 com.ainews.briefing.plist install-task.ps1 \
	         prompt-custom-brief.md custom-brief.sh custom-brief.ps1 commands/custom-brief.md; do \
		if [ -f "$(SCRIPT_DIR)/$$f" ]; then \
			printf "  %-36s \033[32mOK\033[0m\n" "$$f"; \
		else \
			printf "  %-36s \033[31mMISSING\033[0m\n" "$$f"; \
			errors=$$((errors + 1)); \
		fi; \
	done; \
	if [ $$errors -gt 0 ]; then \
		echo ""; \
		echo "$$errors file(s) missing."; \
		exit 1; \
	fi
	@echo ""
	@echo "Checking prompt.md structure..."
	@for section in "Step 0" "Step 1" "Step 2" "Step 3"; do \
		if grep -q "$$section" "$(SCRIPT_DIR)/prompt.md"; then \
			printf "  %-36s \033[32mOK\033[0m\n" "$$section"; \
		else \
			printf "  %-36s \033[31mMISSING\033[0m\n" "$$section"; \
		fi; \
	done
	@echo ""
	@echo "All checks passed."

prompt: ## Print the current prompt
	@cat "$(SCRIPT_DIR)/prompt.md"

## —— Info —————————————————————————————————————————————
info: ## Show project configuration summary
	@echo ""
	@echo "  AI News Briefing — Configuration"
	@echo "  ═════════════════════════════════"
	@echo ""
	@echo "  Platform:    $(PLATFORM)"
	@echo "  Script dir:  $(SCRIPT_DIR)"
	@echo "  Log dir:     $(LOG_DIR)"
	@echo "  Today's log: $(LOG_FILE)"
	@echo ""
	@echo "  CLI pref:    $${AI_BRIEFING_CLI:-auto (claude > codex > gemini > copilot)}"
	@echo "  Model:       $${AI_BRIEFING_MODEL:-opus}"
	@echo "  Topics:      $$(grep -c '^\d\.' "$(SCRIPT_DIR)/prompt.md" 2>/dev/null || echo 9)"
	@echo ""
	@echo "  Engines installed:"
	@for cli in claude codex gemini copilot; do \
		if command -v $$cli >/dev/null 2>&1; then \
			printf "    %-12s \033[32m✓\033[0m\n" "$$cli"; \
		else \
			printf "    %-12s \033[2m✗\033[0m\n" "$$cli"; \
		fi; \
	done
	@echo ""
