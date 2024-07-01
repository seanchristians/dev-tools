.PHONY: install macos start-mmd-service

USER_NAME	= $(shell /usr/bin/id -unr)
USER_ID		= $(shell /usr/bin/id -ur)
USER_HOME	= $(shell /usr/bin/dscl -plist . read "/Users/$(USER_NAME)" NFSHomeDirectory | /usr/bin/plutil -extract 'dsAttrTypeStandard:NFSHomeDirectory.0' raw -)
BIN_DIR		= $(USER_HOME)/.bin

PLATFORM	= $(shell uname -s)

install:
ifeq ($(PLATFORM), Darwin)
	@$(MAKE) macos
else
	@echo This project does not target the current platform.
endif

# Downloads manager
MMD-SERVICE_NAME	= com.seanchristians.macos-manage-downloads

MACOS_TARGETS=\
	$(BIN_DIR)\
	$(BIN_DIR)/manage-downloads.sh\
	$(USER_HOME)/Library/LaunchAgents/$(MMD-SERVICE_NAME).plist

macos: $(MACOS_TARGETS)
	@echo Install complete.

$(BIN_DIR):
	/bin/mkdir -p "$(BIN_DIR)"

$(BIN_DIR)/manage-downloads.sh: manage-downloads/manage-downloads.sh
	/bin/cp manage-downloads/manage-downloads.sh $(BIN_DIR)/manage-downloads.sh
	$(MAKE) start-mmd-service

$(USER_HOME)/Library/LaunchAgents/$(MMD-SERVICE_NAME).plist: manage-downloads/$(MMD-SERVICE_NAME).plist
	/bin/mkdir -p "$(USER_HOME)/Library/LaunchAgents"
	/bin/cp manage-downloads/$(MMD-SERVICE_NAME).plist "$(USER_HOME)/Library/LaunchAgents/$(MMD-SERVICE_NAME).plist"

start-mmd-service: $(USER_HOME)/Library/LaunchAgents/$(MMD-SERVICE_NAME).plist
	-/bin/launchctl bootout "gui/$(USER_ID)" "$(USER_HOME)/Library/LaunchAgents/$(MMD-SERVICE_NAME).plist"
	/bin/launchctl bootstrap "gui/$(USER_ID)" "$(USER_HOME)/Library/LaunchAgents/$(MMD-SERVICE_NAME).plist"
	/bin/launchctl enable "gui/$(USER_ID)/$(MMD-SERVICE_NAME)"