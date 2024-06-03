#!/bin/sh

# Get the GitHub Token from GitHub Action inputs
GITHUB_TOKEN=$1

# Get the pull request number from the GitHub event payload
pull_request_number=$(jq --raw-output .pull_request.number "$GITHUB_EVENT_PATH")
echo PR Number - $pull_request_number

npm install 
npm run build

# Zip the build folder
RUN zip -r build.zip build

# Upload the zip file to GitHub Releases
upload_url=$(curl -sH "Authorization: token $GITHUB_TOKEN" \
  -H "Content-Type: application/zip" \
  --upload-file build.zip \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/latest/assets?name=build.zip" | jq -r '.browser_download_url')

# Post a comment on the pull request with the link to the zip file
comment_response=$(curl -sX POST -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -d "{\"body\": \"### PR - #$pull_request_number. \n ### 🎉 Here is your build zip file! \n [Download Build Zip]($upload_url) \"}" \
  "https://api.github.com/repos/$GITHUB_REPOSITORY/issues/$pull_request_number/comments")

# Extract and print the comment URL from the comment response
comment_url=$(echo "$comment_response" | jq --raw-output .html_url)

echo "Comment posted at: $comment_url"
