FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    openjdk-25-jdk \
    maven \
    && rm -rf /var/lib/apt/lists/*

# Files must be copied here at runtime using --mount 
WORKDIR /usr/src/app

CMD ["/bin/bash"]