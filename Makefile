
.PHONY: prerequisites install install_relay install_tailscale_only

BIN_DEST_DIR=/usr/local/bin/
PLIST_DEST_DIR=/Library/LaunchDaemons/
PLIST_NAME=com.georgeharker.vpn-killswitch.plist

install: prerequisites
	sudo cp vpn-killswitch.sh $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chown root $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chmod 755 $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo cp com.georgeharker.vpn-killswitch.plist $(PLIST_DEST_DIR)/$(PLIST_NAME)
	sudo chmod 644 $(PLIST_DEST_DIR)/$(PLIST_NAME)
	sudo launchctl load -w $(PLIST_DEST_DIR)/$(PLIST_NAME)
	@echo "Installed with Tailscale bypass enabled, iCloud Private Relay disabled"

install_relay: prerequisites
	sudo cp vpn-killswitch.sh $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chown root $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chmod 755 $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo cp com.georgeharker.vpn-killswitch-relay.plist $(PLIST_DEST_DIR)/$(PLIST_NAME)
	sudo chmod 644 $(PLIST_DEST_DIR)/$(PLIST_NAME)
	sudo launchctl load -w $(PLIST_DEST_DIR)/$(PLIST_NAME)
	@echo "Installed with both Tailscale and iCloud Private Relay bypass enabled"

install_tailscale_only: prerequisites
	sudo cp vpn-killswitch.sh $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chown root $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chmod 755 $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo cp com.georgeharker.vpn-killswitch-tailscale-only.plist $(PLIST_DEST_DIR)/$(PLIST_NAME)
	sudo chmod 644 $(PLIST_DEST_DIR)/$(PLIST_NAME)
	sudo launchctl load -w $(PLIST_DEST_DIR)/$(PLIST_NAME)
	@echo "Installed with Tailscale bypass only (same as default install)"

remove:
	sudo launchctl unload -w $(PLIST_DEST_DIR)/$(PLIST_NAME) 2>/dev/null || true
	sudo rm -f $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo rm -f $(PLIST_DEST_DIR)/$(PLIST_NAME)

prerequisites:
	brew install iproute2mac jq

