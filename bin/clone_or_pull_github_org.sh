#!/bin/bash
# Fetch all pages sequentially
PAGE=1
while true; do
  REPOS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/orgs/$ORGNAME/repos?per_page=100&page=$PAGE")
  
  [ "$(echo "$REPOS" | jq length)" -eq 0 ] && break  # Exit when no more repos
  
  echo "$REPOS" | jq -r '.[].ssh_url' | while read url; do
    # Extract the repo name from the URL
    REPO_NAME=$(basename "$url" .git)
    
    # Check if the repo already exists
    if [ -d "$REPO_NAME" ]; then
      echo "Updating existing repository: $REPO_NAME"
      (cd "$REPO_NAME" && git pull)
    else
      echo "Cloning new repository: $REPO_NAME"
      git clone "$url"
    fi
  done
  
  PAGE=$((PAGE + 1))
done
