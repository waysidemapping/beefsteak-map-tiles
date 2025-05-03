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

# Set up the working directory in the container
WORKDIR /usr/src/app

# Create the 'scratch' directory under '/usr/src/app'
RUN mkdir /usr/src/app/scratch

# Create the volume for the planet file (this is for mounting)
VOLUME ["/usr/src/app/scratch"]

COPY install.sh .
COPY rustic ./rustic

# Make the install.sh script executable
RUN chmod +x install.sh

# Set default command to bash (so the container doesn't exit immediately)
CMD ["/usr/src/app/install.sh"]
