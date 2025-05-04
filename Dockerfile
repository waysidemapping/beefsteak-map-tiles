FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive

# Update the apt repository and install necessary utilities
RUN apt update && \
    apt install -y \
    curl \
    bash \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Files must be copied here at runtime using --mount 
WORKDIR /usr/src/app

# Always run start.sh when starting the container
CMD ["/usr/src/app/start.sh"]
