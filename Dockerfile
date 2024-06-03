# Container image that runs your code
FROM ubuntu

# Install necessary packages and Node.js version 20
RUN apt update && \
    apt install -y curl jq zip bash && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt install -y nodejs npm

# Copy your entrypoint script to the container file path
COPY entrypoint.sh /entrypoint.sh

# Make the script executable
RUN chmod +x /entrypoint.sh

# Code file to execute when the docker container starts up (`entrypoint.sh`)
ENTRYPOINT ["/entrypoint.sh"]
