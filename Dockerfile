# Container image that runs your code
FROM alpine:3.10

# Install necessary packages and Node.js version 20
RUN apk update && \
    apk add --no-cache curl jq zip && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apk add --no-cache nodejs npm

# Copy your entrypoint script to the container file path
COPY entrypoint.sh /entrypoint.sh

# Make the script executable
RUN chmod +x /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
