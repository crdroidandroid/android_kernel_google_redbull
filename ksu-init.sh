#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- CONFIGURATION ---
REPO_DIR="KernelSU-Next"
SETUP_URL="https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh"
API_URL="https://api.github.com/repos/KernelSU-Next/KernelSU-Next/releases/latest"
PATCH_BASE_URL="https://raw.githubusercontent.com/crdroidandroid/android_kernel_google_redbull/refs/heads/ksun-patches"


print_msg() {
    case "$1" in
        "GREEN") echo -e "\033[0;32m$2\033[0m" ;;
        "RED") echo -e "\033[0;31m$2\033[0m" ;;
        "YELLOW") echo -e "\033[0;33m$2\033[0m" ;;
        "BLUE") echo -e "\033[0;34m$2\033[0m" ;;
        *) echo "$2" ;;
    esac
}

get_latest_release_tag() {
    print_msg "BLUE" "Fetching the latest release tag from GitHub..." >&2

    local latest_tag
    latest_tag=$(curl -s "$API_URL" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -z "$latest_tag" ]; then
        print_msg "RED" "Error: Could not fetch the latest release tag. Please check your connection or the GitHub API status." >&2
        exit 1
    fi

    # Convert the tag to lowercase and return it
    echo "$latest_tag" | tr '[:upper:]' '[:lower:]'
}

apply_patch() {
    print_msg "BLUE" "Starting patch application process..."

    # Ensure we are in the repository directory before proceeding
    if [ ! -d "$REPO_DIR" ]; then
        print_msg "RED" "Error: '$REPO_DIR' directory not found." >&2
        exit 1
    fi

    cd "$REPO_DIR"

    local version_tag
    version_tag=$(get_latest_release_tag)

    print_msg "GREEN" "Latest version tag found: $version_tag"

    # Construct the patch filename and URL
    local patch_filename="0001-kernel-implement-susfs-v1.5.5-v1.5.7-KSUN-${version_tag}.patch"
    local patch_url="${PATCH_BASE_URL}/${patch_filename}"

    print_msg "BLUE" "Downloading patch: $patch_url"

    rm -f *.patch

    if ! wget -q "$patch_url"; then
        print_msg "RED" "Error: Failed to download patch file. It may not exist for tag '$version_tag'." >&2
        cd ..
        exit 1
    fi

    print_msg "BLUE" "Applying patch: $patch_filename"

    if patch -p1 < "$patch_filename"; then
        print_msg "GREEN" "Patch applied successfully."
        print_msg "BLUE" "Cleaning up patch file..."
        rm "$patch_filename"
    else
        print_msg "RED" "Error: Patch failed to apply. Hunks may have failed. Please check for conflicts." >&2
        print_msg "YELLOW" "The failed patch file '$patch_filename' has been left for inspection."
        cd ..
        exit 1
    fi

    cd ..
    print_msg "GREEN" "Patch process completed successfully."
}

normal_operation() {
    print_msg "BLUE" "Performing normal installation..."

    if [ -d "$REPO_DIR" ]; then
        print_msg "RED" "Error: '$REPO_DIR' directory already exists. Use --update or --clean." >&2
        exit 1
    fi

    print_msg "BLUE" "Running setup script from $SETUP_URL..."
    if ! curl -LSs "$SETUP_URL" | bash -s next; then
        print_msg "RED" "Error: The setup script failed to execute." >&2
        exit 1
    fi

    apply_patch

    print_msg "GREEN" "Normal installation complete."
}

update_operation() {
    print_msg "BLUE" "Performing update..."

    if [ ! -d "$REPO_DIR" ]; then
        print_msg "YELLOW" "'$REPO_DIR' directory not found. Running a normal installation instead."
        normal_operation
        return
    fi

    cd "$REPO_DIR"
    print_msg "BLUE" "Pulling latest changes from git..."
    if ! git pull; then
        print_msg "RED" "Error: 'git pull' failed. Please resolve any conflicts manually and try again." >&2
        cd ..
        exit 1
    fi
    cd ..

    # After updating the repo, apply the latest patch
    apply_patch

    print_msg "GREEN" "Update complete."
}

clean_operation() {
    print_msg "BLUE" "Performing clean installation..."

    if [ -d "$REPO_DIR" ]; then
        print_msg "YELLOW" "Removing existing '$REPO_DIR' directory."
        rm -rf "$REPO_DIR"
    fi

    normal_operation

    print_msg "GREEN" "Clean installation complete."
}


if [ "$1" == "--clean" ]; then
    clean_operation
elif [ "$1" == "--update" ]; then
    update_operation
# If no arguments are provided, check the state of the directory
elif [ -d "$REPO_DIR" ]; then
    print_msg "YELLOW" "'$REPO_DIR' directory detected."
    # Prompt the user for action
    read -p "Would you like to [U]pdate the existing repository or perform a [C]lean install? (U/C): " -n 1 -r
    echo # Move to a new line
    case $REPLY in
        [Uu]* )
            update_operation
            ;;
        [Cc]* )
            clean_operation
            ;;
        * )
            print_msg "RED" "Invalid choice. Exiting."
            exit 1
            ;;
    esac
else

    print_msg "BLUE" "'$REPO_DIR' directory not found. Starting normal installation."
    normal_operation
fi

print_msg "GREEN" "\nAll operations finished successfully."
exit 0
