#!/bin/bash
# Fetch all pages sequentially
PAGE=1
while true; do
  REPOS=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/orgs/$ORGNAME/repos?per_page=100&page=$PAGE")
  
  [ "$(echo "$REPOS" | jq length)" -eq 0 ] && break  # Exit when no more repos
  
  echo "$REPOS" | jq -r '.[].ssh_url' | while read url; do
    git clone "$url"
  done
  
  PAGE=$((PAGE + 1))
done

