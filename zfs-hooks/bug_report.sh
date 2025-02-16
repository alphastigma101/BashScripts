#!/bin/bash
system_update_bug_report() {
    echo -e "### Bug Report: Issue with Kernel Update Detection in bash script\n"
    echo -e "#### Description:\n"
    echo -e "The script fails to correctly parse or match kernel packages ending with numeric versions. This issue affects the detection of installed kernel versions when running the script for Gentoo systems. Specifically, `gentoo-sources` or other kernel packages with numeric versions are not being detected properly, which impacts further operations in the script.\n"
    echo -e "#### Steps to Reproduce:\n"
    echo -e "#### How to Report a Bug:\n"
    echo -e "1. Visit the repository issues page: https://github.com/alphastigma101/BashScripts/issues\n"
    echo -e "2. Click on 'New Issue' to create a bug report.\n"
    echo -e "3. Provide a detailed description of the issue, including steps to reproduce the error and the expected vs. actual behavior.\n"
    echo -e "4. Include the relevant logs or output from running the script, as well as any error messages.\n"
    echo -e "5. Be sure to include your system and environment details such as Gentoo version, Portage version, and Bash version.\n"
    echo -e "\n#### Expected Behavior:\n"
    echo -e "The script should correctly parse and list installed kernel versions with numeric versioning, specifically matching lines like 'sys-kernel/gentoo-sources:6.1.118'.\n"
    echo -e "\n#### Actual Behavior:\n"
    echo -e "The script fails to detect or properly handle kernel packages that end with numeric versions (e.g., 'sys-kernel/gentoo-sources:6.1.118') and does not store them in the dictionary.\n"
    echo -e "\n#### Environment:\n"
    echo -e " - Operating System: Gentoo Linux\n"
    echo -e " - Script Version: $(git describe --tags)\n"
    echo -e " - Bash version: $(bash --version | head -n 1)\n"
    echo -e " - Portage version: $(emerge --info | grep -i 'portage' | head -n 1)\n"
    echo -e "\n#### Logs/Output:\n"
    echo -e "Please provide any additional log output below that could help identify the root cause of the issue.\n"
    echo -e "For example:\n"
    echo -e " - Output from running the kernel update script.\n"
    echo -e " - Any error messages.\n"
}
