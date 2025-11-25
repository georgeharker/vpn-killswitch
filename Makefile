
.PHONY: prerequisites install

BIN_DEST_DIR=/usr/local/bin/
PLIST_DEST_DIR=/Library/LaunchDaemons/

install: prerequisites
	sudo cp vpn-killswitch.sh $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chown root $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chmod 755 $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo cp com.georgeharker.vpn-killswitch.plist $(PLIST_DEST_DIR)
	sudo chmod 655 $(PLIST_DEST_DIR)/com.georgeharker.vpn-killswitch.plist
	sudo launchctl load -w $(PLIST_DEST_DIR)/com.georgeharker.vpn-killswitch.plist

install_relay: prerequisites
	sudo cp vpn-killswitch.sh $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chown root $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo chmod 755 $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo cp com.georgeharker.vpn-killswitch-relay.plist $(PLIST_DEST_DIR)
	sudo chmod 655 $(PLIST_DEST_DIR)/com.georgeharker.vpn-killswitch.plist
	sudo launchctl load -w $(PLIST_DEST_DIR)/com.georgeharker.vpn-killswitch.plist

remove:
	sudo launchctl unload -w $(PLIST_DEST_DIR)/com.georgeharker.vpn-killswitch.plist
	sudo rm $(BIN_DEST_DIR)/vpn-killswitch.sh
	sudo rm $(PLIST_DEST_DIR)/com.georgeharker.vpn-killswitch.plist 

prerequisites:
	brew install iproute2mac jq

