#!/bin/bash

# Define your repos here
REPOS=(
    "https://github.com/ipeirotis/dealing-with-data.git"
    "https://github.com/ipeirotis/oral-exam-agent.git"
    "https://github.com/ipeirotis-org/scholar_v2.git"
)

TARGET_DIR="/home/user/repos"
mkdir -p "$TARGET_DIR"

for repo in "${REPOS[@]}"; do
    # Extract repo name from URL (e.g., 'dealing-with-data')
    repo_name=$(basename "$repo" .git)
    
    if [ ! -d "$TARGET_DIR/$repo_name" ]; then
        echo "Cloning $repo_name..."
        git clone "$repo" "$TARGET_DIR/$repo_name"
    else
        echo "$repo_name already exists. Skipping clone to preserve changes."
    fi
done
