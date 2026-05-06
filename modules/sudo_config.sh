#!/usr/bin/env bash
# Adds user to sudo group and optionally enables pwfeedback

config_sudo() {
    echo -e "${YELLOW}Configuring sudo...${NC}"


    if groups "$USER" | grep -qE '\bsudo\b'; then
        echo "User is already in the sudo group."
    else
        echo "Adding user '$USER' to sudo group..."
        if sudo usermod -aG sudo "$USER"; then
            echo -e "${GREEN}Done. Note: you need to log out and back in for group changes to take effect.${NC}"
        else
            echo -e "${RED}Failed to add user to sudo group.${NC}"
            return 1
        fi
    fi

    local answer
    answer=$(whiptail --title "Sudo Password Feedback" \
        --yesno "Show asterisks when typing the sudo password?" 8 60 3>&1 1>&2 2>&3)
    local exitstatus=$?
    if [ $exitstatus -eq 0 ]; then
        echo 'Defaults pwfeedback' | sudo tee /etc/sudoers.d/pwfeedback > /dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Password feedback enabled.${NC}"
        else
            echo -e "${RED}Failed to create /etc/sudoers.d/pwfeedback.${NC}"
        fi
    else
        echo "Skipping password feedback setting."
    fi
}
