#!/bin/sh

# Get the GitHub Token from GitHub Action inputs
GITHUB_TOKEN=$1

# Validate GitHub Token
if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GitHub token not provided."
  exit 1
fi

# Validate GitHub Event Path
if [ -z "$GITHUB_EVENT_PATH" ]; then
  echo "Error: GitHub event path not provided."
  exit 1
fi

# Get the pull request number from the GitHub event payload
if [ ! -f "$GITHUB_EVENT_PATH" ]; then
  echo "Error: GitHub event path not found."
  exit 1
fi

pull_request_number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
if [ -z "$pull_request_number" ]; then
  echo "Error: Pull request number not found."
  exit 1
fi
echo "PR Number - $pull_request_number"

# Clone the repository
git clone "https://x-access-token:$GITHUB_TOKEN@github.com/$GITHUB_REPOSITORY.git"
cd "$(basename "$GITHUB_REPOSITORY" .git)"

# update
npm update
if [ $? -ne 0 ]; then
  echo "Error: npm install failed."
  exit 1
fi

# Install npm dependencies and build project
npm install
if [ $? -ne 0 ]; then
  echo "Error: npm install failed."
  exit 1
fi

npm run build
if [ $? -ne 0 ]; then
  echo "Error: npm run build failed."
  exit 1
fi

# Check if build folder exists
if [ ! -d build ]; then
  echo "Error: build directory not found."
  exit 1
fi

# Zip the build folder
zip -r build.zip build
if [ $? -ne 0 ]; then
  echo "Error: Failed to create zip file."
  exit 1
fi

# Create a new release
release_response=$(curl -sX POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{\"tag_name\": \"pr-$pull_request_number-build\", \"name\": \"PR #$pull_request_number Build\", \"body\": \"Build for PR #$pull_request_number\"}" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/releases")

# Extract the upload URL for the release
upload_url=$(echo "$release_response" | jq -r '.upload_url' | sed -e "s/{?name,label}//")

if [ -z "$upload_url" ]; then
  echo "Error: Unable to create a new release."
  exit 1
fi

# Upload the zip file to the release
upload_response=$(curl -sX POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/zip" \
  --data-binary @build.zip \
  "$upload_url?name=build.zip")

# Extract the browser download URL from the upload response
browser_download_url=$(echo "$upload_response" | jq -r '.browser_download_url')

if [ -z "$browser_download_url" ]; then
  echo "Error: Failed to upload the zip file."
  exit 1
fi

# Post a comment on the pull request with the link to the zip file
comment_response=$(curl -sX POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{\"body\": \"### PR - #$pull_request_number. \n ### 🎉 Here is your build zip file! \n [Download Build Zip]($browser_download_url) \"}" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$pull_request_number/comments")

# Extract and print the comment URL from the comment response
comment_url=$(echo "$comment_response" | jq --raw-output .html_url)

if [ -z "$comment_url" ]; then
  echo "Error: Failed to post a comment on the pull request."
  exit 1
fi

echo "Comment posted at: $comment_url"
