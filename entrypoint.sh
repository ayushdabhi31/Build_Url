#!/bin/bash

set -e

# Get the GitHub token and event path from the script arguments
GITHUB_TOKEN=$1
GITHUB_EVENT_PATH=$2

# Debugging: Print the event path and token (remove or mask sensitive data in logs)
echo "GITHUB_EVENT_PATH: $GITHUB_EVENT_PATH"
echo "GITHUB_TOKEN: $GITHUB_TOKEN"

# Navigate to the repository
cd "$GITHUB_WORKSPACE"

# Run the build command
npm install
npm run build

# Zip the build directory
zip -r build.zip build

# Get the pull request number
PR_NUMBER=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
TAG="pr-${PR_NUMBER}-build"

# Create a release
release_response=$(curl -sX POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{\"tag_name\": \"$TAG\", \"name\": \"$TAG\", \"body\": \"Release for PR #$PR_NUMBER\"}" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/releases")

# Verify release response
echo "$release_response"

# Extract the upload URL for the release
upload_url=$(echo "$release_response" | jq --raw-output .upload_url | sed "s/{?name,label}//")

if [ -z "$upload_url" ]; then
  echo "Error: Failed to create a release."
  echo "Response: $release_response"
  exit 1
fi

# Upload the build.zip file to the release
upload_response=$(curl -sX POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/zip" \
  --data-binary @build.zip \
  "$upload_url?name=build.zip")

# Extract the download URL for the uploaded file
download_url=$(echo "$upload_response" | jq --raw-output .browser_download_url)

if [ -z "$download_url" ]; then
  echo "Error: Failed to upload the build.zip file."
  echo "Response: $upload_response"
  exit 1
fi

# Post a comment on the pull request with the link to the zip file
comment_response=$(curl -sX POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{\"body\": \"### PR - #$PR_NUMBER. \n ### 🎉 Here is your build zip file! \n [Download Build Zip]($download_url) \"}" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$PR_NUMBER/comments")

# Extract and print the comment URL from the comment response
comment_url=$(echo "$comment_response" | jq --raw-output .html_url)

if [ -z "$comment_url" ]; then
  echo "Error: Failed to post a comment on the pull request."
  echo "Response: $comment_response"
  exit 1
fi

echo "Comment posted at: $comment_url"
