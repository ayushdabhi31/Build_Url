#!/bin/sh

# Get the GitHub Token from GitHub Action inputs
GITHUB_TOKEN=$1

# Get the pull request number from the GitHub event payload
pull_request_number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
echo PR Number - $pull_request_number

# Fetch repository contents from GitHub
repo_contents_response=$(curl -sX GET -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/contents")

# Check if the repository contents were fetched successfully
if [ "$(echo "$repo_contents_response" | jq -r '.message')" = "Not Found" ]; then
  echo "Error: Unable to fetch repository contents"
  exit 1
fi

# Find package.json in the repository contents
package_json=$(echo "$repo_contents_response" | jq -r '.[] | select(.name == "package.json")')

# Check if package.json was found
if [ -z "$package_json" ]; then
  echo "Error: package.json file not found in the repository"
  exit 1
fi

# Extract the download URL for package.json
package_json_url=$(echo "$package_json" | jq -r '.download_url')

# Download package.json
curl -sSL "$package_json_url" -o package.json

# Extract the homepage URL from package.json
build_url=$(jq -r '.homepage' package.json)

# Check if build_url is empty
if [ -z "$build_url" ]; then
  echo "Error: homepage URL not found in package.json"
  exit 1
fi

build_url=$(echo jq -r '.homepage' package.json)

# Create a comment with the GIF on the pull request
comment_response=$(curl -sX POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{\"body\": \"### PR - #$pull_request_number. \n ### 🎉 Here is your build url! \n ($build_url) \"}" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$pull_request_number/comments")

# Extract and print the comment URL from the comment response
comment_url=$(echo "$comment_response" | jq --raw-output .html_url)
