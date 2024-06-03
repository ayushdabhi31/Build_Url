# Container image that runs your code
FROM alpine:3.10

# # Install necessary packages
RUN apk update && \
    apk add --no-cache curl jq

# Copy your entrypoint script to the container file path
COPY entrypoint.sh /entrypoint.sh

# Make the script executable
RUN chmod +x /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]