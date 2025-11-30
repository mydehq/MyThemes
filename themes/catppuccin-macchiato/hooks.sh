# Install hooks.
# This file will be sourced while installing a theme.
# USER WILL BE ASKED BEFORE EXECUTING THE HOOK.

# Hooks Available:
#        1. pre_install  - Execute before installation.
#        2. post_install - Execute after installation.
#        3. pre_upgrade  - Execute before upgrade.
#        4. post_upgrade - Execute after upgrade.
#        5. pre_remove   - Execute before removal.
#        6. post_remove  - Execute after removal.


pre_install() {
    echo "Pre-install hook executed."
}

post_install() {
    echo "Post-install hook executed."
}

#----------------

pre_upgrade() {
    echo "Pre-upgrade hook executed."
}

post_upgrade() {
    echo "Post-upgrade hook executed."
}

#----------------

pre_remove() {
    echo "Pre-remove hook executed."
}

post_remove() {
    echo "Post-remove hook executed."
}
