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

# Install Node.js and npm
apt update && apt install -y nodejs npm
if [ $? -ne 0 ]; then
  echo "Error: Failed to install Node.js and npm."
  exit 1
fi

# Fetch repository contents from GitHub
repo_contents_response=$(curl -sX GET -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/contents")

# Check if the repository contents were fetched successfully
if echo "$repo_contents_response" | jq -e '.message'; then
  echo "Error: $(echo "$repo_contents_response" | jq -r '.message')"
  exit 1
fi

# Find package.json in the repository contents
package_json=$(echo "$repo_contents_response" | jq -r '.[] | select(.name == "package.json")')

# Check if package.json was found
if [ -z "$package_json" ]; then
  echo "Error: package.json file not found in the repository"
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

# Get the latest release ID
release_id=$(curl -sH "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/latest" | jq -r .id)

if [ -z "$release_id" ]; then
  echo "Error: Unable to fetch the latest release ID."
  exit 1
fi

# Upload the zip file to GitHub Releases
upload_url=$(curl -sH "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/zip" \
  --data-binary @build.zip \
  "https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases/$release_id/assets?name=build.zip" | jq -r '.browser_download_url')

if [ -z "$upload_url" ]; then
  echo "Error: Failed to upload the zip file."
  exit 1
fi

# Post a comment on the pull request with the link to the zip file
comment_response=$(curl -sX POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{\"body\": \"### PR - #$pull_request_number. \n ### 🎉 Here is your build zip file! \n [Download Build Zip]($upload_url) \"}" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$pull_request_number/comments")

# Extract and print the comment URL from the comment response
comment_url=$(echo "$comment_response" | jq --raw-output .html_url)

if [ -z "$comment_url" ]; then
  echo "Error: Failed to post a comment on the pull request."
  exit 1
fi

echo "Comment posted at: $comment_url"
